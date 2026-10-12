import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/list_query_helpers.dart';
import 'package:kover/database/tables/bookmarks.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/series.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks, Chapters, Series])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.attachedDatabase);

  /// Whether a bookmark exists for [page] of [chapterId] and is not marked as
  /// removed.
  Stream<bool> watchPageBookmark({
    required int chapterId,
    required int page,
    int pageOffset = 0,
    String? xPath,
  }) {
    final query = selectOnly(bookmarks)
      ..addColumns([bookmarks.id])
      ..where(
        bookmarks.chapterId.equals(chapterId) &
            bookmarks.page.equals(page) &
            bookmarks.removed.equals(false) &
            bookmarks.imageOffset.equals(pageOffset) &
            bookmarks.xPath.equalsNullable(xPath),
      );
    return query.watch().map((rows) => rows.isNotEmpty);
  }

  /// Every non-removed bookmark in the given scope, restricted to image
  /// chapters and ordered by chapter sort order then page.
  Stream<List<BookmarkData>> watchBookmarks({
    int? seriesId,
    int? volumeId,
    int? chapterId,
  }) {
    final q =
        select(bookmarks).join([
          innerJoin(chapters, chapters.id.equalsExp(bookmarks.chapterId)),
        ])..where(
          bookmarks.removed.equals(false) &
              isBookmarkableChapterFormat(chapters.format),
        );

    if (seriesId != null) {
      q.where(bookmarks.seriesId.equals(seriesId));
    }
    if (volumeId != null) {
      q.where(bookmarks.volumeId.equals(volumeId));
    }
    if (chapterId != null) {
      q.where(bookmarks.chapterId.equals(chapterId));
    }

    q.orderBy([
      OrderingTerm.asc(chapters.sortOrder),
      OrderingTerm.asc(bookmarks.page),
    ]);

    return q.map((r) => r.readTable(bookmarks)).watch();
  }

  /// Get every locally stored bookmark row that has been modified since the
  /// last sync.
  Future<List<BookmarkData>> getDirtyBookmarks() {
    return (select(bookmarks)..where((b) => b.dirty.equals(true))).get();
  }

  /// Get the bookmark for [page] of [chapterId].
  Future<BookmarkData?> getBookmark({
    required int chapterId,
    required int page,
    int imageOffset = 0,
    String? xPath,
  }) {
    return (select(bookmarks)
          ..where(
            (b) =>
                b.chapterId.equals(chapterId) &
                b.page.equals(page) &
                b.imageOffset.equals(imageOffset) &
                b.xPath.equalsNullable(xPath),
          )
          ..orderBy([(b) => OrderingTerm.asc(b.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Every locally stored, non-removed bookmark row, dirty and clean alike.
  /// Used to reconcile against the remote set during a full refresh.
  Future<List<BookmarkData>> getBookmarks() {
    return (select(bookmarks)..where((b) => b.removed.equals(false))).get();
  }

  /// Mark the bookmark with [id] as removed.
  Future<void> markRemoved(int id) {
    return (update(bookmarks)..where((b) => b.id.equals(id))).write(
      const BookmarksCompanion(dirty: Value(true), removed: Value(true)),
    );
  }

  /// Delete the bookmarks with the given [ids] from the local database.
  Future<void> deleteByIds(Iterable<int> ids) async {
    await (delete(bookmarks)..where((b) => b.id.isIn(ids))).go();
  }

  /// Mark the bookmarks with the given [ids] as clean, indicating that they have
  /// been successfully synced with the server.
  Future<void> clearDirtyFlags(Iterable<int> ids) async {
    await (update(bookmarks)..where((b) => b.id.isIn(ids))).write(
      const BookmarksCompanion(dirty: Value(false)),
    );
  }

  /// Add or update a bookmark entry.
  Future<BookmarkData> upsert(BookmarksCompanion entry) {
    return transaction(() async {
      final existing = await getBookmark(
        chapterId: entry.chapterId.value,
        page: entry.page.value,
        imageOffset: entry.imageOffset.value,
        xPath: entry.xPath.present ? entry.xPath.value : null,
      );
      final id = entry.id.present ? entry.id.value : existing?.id;
      if (id != null) {
        final rows = await (update(bookmarks)..where((b) => b.id.equals(id)))
            .writeReturning(entry.copyWith(id: Value(id)));
        return rows.single;
      }
      return into(bookmarks)
          .insertReturning(entry.copyWith(id: const Value.absent()));
    });
  }

  /// Get the IDs of all chapters that have at least one bookmark. This is used to
  Future<List<int>> getExistingChapterIds() async {
    final q = selectOnly(chapters, distinct: true)..addColumns([chapters.id]);
    return q.map((row) => row.read(chapters.id)!).get();
  }
}
