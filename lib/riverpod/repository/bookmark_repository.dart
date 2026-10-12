import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/bookmark_dto_mappings.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/bookmark_sync_operations.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bookmark_repository.g.dart';

@Riverpod(keepAlive: true)
BookmarkRepository bookmarkRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(restClientProvider);
  return BookmarkRepository(db, BookmarkSyncOperations(client));
}

class BookmarkRepository(
  final AppDatabase _db,
  final BookmarkSyncOperations _client,
) {
  /// Whether a bookmark exists for [page] of [chapterId] and is not marked as
  /// removed.
  Stream<bool> watchPageBookmark({
    required int chapterId,
    required int page,
    int pageOffset = 0,
    String? xPath,
  }) {
    return _db.bookmarkDao.watchPageBookmark(
      chapterId: chapterId,
      page: page,
      pageOffset: pageOffset,
      xPath: xPath,
    );
  }

  /// Every non-removed image bookmark in the given scope, ordered by chapter
  /// sort order then page.
  Stream<List<BookmarkModel>> watchBookmarks({
    int? seriesId,
    int? volumeId,
    int? chapterId,
  }) => _db.bookmarkDao
      .watchBookmarks(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      )
      .map((l) => l.map(BookmarkModel.fromDatabaseModel).toList());

  /// Adds a bookmark for [page] of [chapterId]. If a bookmark already exists for
  /// that page, it is updated. The bookmark is marked as dirty and a request is
  /// sent to the server to add it. If the server request fails, the bookmark
  /// remains dirty and will be retried on the next sync.
  Future<void> addBookmark({
    required int seriesId,
    required int volumeId,
    required int chapterId,
    required int page,
    int imageOffset = 0,
    String? xPath,
  }) async {
    final stored = await _db.bookmarkDao.upsert(
      BookmarksCompanion(
        seriesId: Value(seriesId),
        volumeId: Value(volumeId),
        chapterId: Value(chapterId),
        page: Value(page),
        imageOffset: Value(imageOffset),
        xPath: Value(xPath),
        dirty: const Value(true),
        removed: const Value(false),
      ),
    );

    log.debug(
      'adding bookmark',
      attributes: {
        'series_id': seriesId,
        'volume_id': volumeId,
        'chapter_id': chapterId,
        'page': page,
        'image_offset': imageOffset,
        'xpath': xPath,
        'stored': stored,
      },
    );

    try {
      await _client.add(stored.toBookmarkDto());
      await _db.bookmarkDao.clearDirtyFlags([stored.id]);
    } catch (e) {
      log.info('could not add bookmark', attributes: {'error': e});
    }
  }

  /// Removes the bookmark for [page] of [chapterId], if it exists. If the
  /// bookmark has never been successfully pushed to the server, it is
  /// hard-deleted. If it has been pushed, it is marked as removed and a
  /// request is sent to the server to remove it. If the server request fails,
  /// the bookmark remains marked as removed and will be retried on the next
  /// sync.
  Future<void> removeBookmark({
    required int chapterId,
    required int page,
    int imageOffset = 0,
    String? xPath,
  }) async {
    final stored = await _db.bookmarkDao.getBookmark(
      chapterId: chapterId,
      page: page,
      imageOffset: imageOffset,
      xPath: xPath,
    );

    log.debug(
      'removing bookmark',
      attributes: {
        'chapter_id': chapterId,
        'page': page,
        'image_offset': imageOffset,
        'xpath': xPath,
        'existing': stored,
      },
    );

    if (stored == null) return;

    if (stored.serverId == null && stored.dirty) {
      // Never successfully pushed: no server copy exists, safe to hard-delete.
      await _db.bookmarkDao.deleteByIds([stored.id]);
      return;
    }

    await _db.bookmarkDao.markRemoved(stored.id);
    try {
      await _client.remove(stored.toBookmarkDto());
      await _db.bookmarkDao.deleteByIds([stored.id]);
    } catch (e) {
      log.info('could not remove bookmark', attributes: {'error': e});
    }
  }

  /// Merges all dirty bookmarks with the server. Dirty bookmarks are those that
  /// have been added or removed locally but not yet successfully pushed to the
  /// server. If a dirty bookmark is successfully pushed, its dirty flag is
  /// cleared. If a dirty bookmark is marked as removed and successfully pushed,
  /// it is hard-deleted locally.
  Future<void> mergeBookmarks() async {
    final dirty = await _db.bookmarkDao.getDirtyBookmarks();
    if (dirty.isEmpty) return;

    final added = <int>[];
    final removed = <int>[];
    for (final bookmark in dirty) {
      try {
        if (bookmark.removed) {
          await _client.remove(bookmark.toBookmarkDto());
          removed.add(bookmark.id);
        } else {
          await _client.add(bookmark.toBookmarkDto());
          added.add(bookmark.id);
        }
      } catch (e, stacktrace) {
        log.error('could not merge bookmark', error: e, stacktrace: stacktrace);
      }
    }

    if (removed.isNotEmpty) await _db.bookmarkDao.deleteByIds(removed);
    if (added.isNotEmpty) await _db.bookmarkDao.clearDirtyFlags(added);
  }

  /// Fetches all bookmarks from the server and merges them with the local
  /// database. This is a full refresh that ensures the local state matches the
  /// server state. It merges remote bookmarks into the local database and
  /// deletes any local bookmarks that are not present on the server, as long
  /// as they are not dirty (i.e., they have no unsynced changes).
  Future<void> refreshAllBookmarks() async {
    final remote = await _client.getAllBookmarks();
    await _mergeRemote(remote);
    await _deleteMissingRemote(remote);
  }

  /// Deletes local rows that are clean (not dirty, not removed) and whose
  /// `(chapterId, page, imageOffset, xPath)` is absent from [remote]. Dirty rows
  /// are never deleted: they hold unsynced local intent.
  Future<void> _deleteMissingRemote(Iterable<BookmarkDto> remote) async {
    final remoteLocations = remote
        .map(
          (dto) => (dto.chapterId, dto.page, dto.imageOffset ?? 0, dto.xPath),
        )
        .toSet();

    final local = await _db.bookmarkDao.getBookmarks();
    final stale = local
        .where(
          (b) =>
              !b.dirty &&
              !remoteLocations.contains((
                b.chapterId,
                b.page,
                b.imageOffset,
                b.xPath,
              )),
        )
        .map((b) => b.id)
        .toList();

    if (stale.isNotEmpty) await _db.bookmarkDao.deleteByIds(stale);
  }

  Future<void> _mergeRemote(Iterable<BookmarkDto> remote) async {
    final existingChapterIds = (await _db.bookmarkDao.getExistingChapterIds())
        .toSet();
    for (final dto in remote) {
      if (!existingChapterIds.contains(dto.chapterId)) {
        log.warning(
          'skipping bookmark for unknown chapter',
          attributes: {'chapter_id': dto.chapterId},
        );
        continue;
      }
      final local = await _db.bookmarkDao.getBookmark(
        chapterId: dto.chapterId,
        page: dto.page,
        imageOffset: dto.imageOffset ?? 0,
        xPath: dto.xPath,
      );
      if (local != null && local.dirty) {
        log.warning(
          'skipping remote bookmark for dirty local row',
          attributes: {
            'chapter_id': dto.chapterId,
            'page': dto.page,
          },
        );
        continue;
      }
      await _db.bookmarkDao.upsert(dto.toBookmarkCompanion());
    }
  }
}
