import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/bookmark_dto_mappings.dart';
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

  //
  // Stream<List<BookmarkModel>> watchChapterBookmarks(int chapterId) => _db
  //     .bookmarkDao
  //     .watchChapterBookmarks(chapterId)
  //     .map((l) => l.map(BookmarkModel.fromDatabaseModel).toList());
  //
  // Stream<List<BookmarkModel>> watchVolumeBookmarks(int volumeId) => _db
  //     .bookmarkDao
  //     .watchVolumeBookmarks(volumeId)
  //     .map((l) => l.map(BookmarkModel.fromDatabaseModel).toList());
  //
  // Stream<List<BookmarkModel>> watchSeriesBookmarks(int seriesId) => _db
  //     .bookmarkDao
  //     .watchSeriesBookmarks(seriesId)
  //     .map((l) => l.map(BookmarkModel.fromDatabaseModel).toList());
  //
  // Stream<List<int>> watchChapterIdsWithBookmarks({
  //   int? seriesId,
  //   int? volumeId,
  // }) => _db.bookmarkDao.watchChapterIdsWithBookmarks(
  //   seriesId: seriesId,
  //   volumeId: volumeId,
  // );
  //
  // Stream<List<SeriesModel>> watchBookmarkedSeries() => _db.bookmarkDao
  //     .watchBookmarkedSeries()
  //     .map((l) => l.map(SeriesModel.fromDatabaseModel).toList());
  //
  // Stream<List<ChapterModel>> watchBookmarkedChapters({
  //   int? seriesId,
  //   int? volumeId,
  // }) => _db.bookmarkDao
  //     .watchBookmarkedChapters(seriesId: seriesId, volumeId: volumeId)
  //     .map((l) => l.map(ChapterModel.fromDatabaseModel).toList());
  //
  Future<void> addBookmark({
    required int seriesId,
    required int volumeId,
    required int chapterId,
    required int page,
    int imageOffset = 0,
    String? xPath,
  }) async {
    // final existing = await _db.bookmarkDao.getBookmark(
    //   chapterId: chapterId,
    //   page: page,
    //   imageOffset: imageOffset,
    //   xPath: xPath,
    // );
    //
    // final BookmarkData stored;
    // if (existing != null) {
    //   stored = await _db.bookmarkDao.updateById(
    //     existing.id,
    //     BookmarksCompanion(
    //       seriesId: Value(seriesId),
    //       volumeId: Value(volumeId),
    //       xPath: Value(xPath),
    //       dirty: const Value(true),
    //       removed: const Value(false),
    //     ),
    //   );
    // } else {
    //   stored = await _db.bookmarkDao.upsertByNaturalKey(
    //     BookmarksCompanion.insert(
    //       seriesId: seriesId,
    //       volumeId: volumeId,
    //       chapterId: chapterId,
    //       page: page,
    //       imageOffset: Value(imageOffset),
    //       xPath: Value(xPath),
    //       dirty: const Value(true),
    //       removed: const Value(false),
    //     ),
    //   );
    // }
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

    try {
      await _client.add(stored.toBookmarkDto());
      await _db.bookmarkDao.clearDirtyFlags([stored.id]);
    } catch (e, stacktrace) {
      log.error('could not add bookmark', error: e, stacktrace: stacktrace);
    }
  }

  Future<void> removeBookmark({
    required int chapterId,
    required int page,
    int imageOffset = 0,
    String? xPath,
  }) async {
    final existing = await _db.bookmarkDao.getBookmark(
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
        'existing': existing,
      },
    );

    if (existing == null) return;

    if (existing.serverId == null && existing.dirty) {
      // Never successfully pushed: no server copy exists, safe to hard-delete.
      await _db.bookmarkDao.deleteByIds([existing.id]);
      return;
    }

    await _db.bookmarkDao.markRemoved(existing.id);
    try {
      await _client.remove(existing.toBookmarkDto());
      await _db.bookmarkDao.deleteByIds([existing.id]);
    } catch (e, stacktrace) {
      log.error('could not remove bookmark', error: e, stacktrace: stacktrace);
    }
  }

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

  Future<void> refreshAllBookmarks() async {
    final remote = await _client.getAllBookmarks();
    await _mergeRemote(remote);
    await _deleteMissingRemote(remote);
  }

  /// Deletes local rows that are clean (not dirty, not removed) and whose
  /// `(chapterId, page, imageOffset)` is absent from [remote]. Dirty rows are
  /// never deleted: they hold unsynced local intent.
  Future<void> _deleteMissingRemote(Iterable<BookmarkDto> remote) async {
    final remoteLocations = remote
        .map((dto) => (dto.chapterId, dto.page, dto.imageOffset ?? 0))
        .toSet();

    final local = await _db.bookmarkDao.getBookmarks();
    final stale = local
        .where(
          (b) =>
              !b.dirty &&
              !remoteLocations.contains((b.chapterId, b.page, b.imageOffset)),
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

      //   // Update in place so the row id (and any dependent state) is preserved
      //   // even when the remote `xPath` differs from the reflowed local value.
      //   await _db.bookmarkDao.updateById(local.id, dto.toBookmarkCompanion());
      // } else {
      //   await _db.bookmarkDao.upsertByNaturalKey(dto.toBookmarkCompanion());
      // }
    }
  }
}
