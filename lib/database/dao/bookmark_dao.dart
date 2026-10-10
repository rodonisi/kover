import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
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

  // Stream<List<BookmarkData>> watchChapterBookmarks(int chapterId) =>
  //     (select(bookmarks)
  //           ..where(
  //             (b) => b.chapterId.equals(chapterId) & b.removed.equals(false),
  //           )
  //           ..orderBy([(b) => OrderingTerm.asc(b.page)]))
  //         .watch();
  //
  // Stream<List<BookmarkData>> watchVolumeBookmarks(int volumeId) =>
  //     (select(bookmarks)
  //           ..where(
  //             (b) => b.volumeId.equals(volumeId) & b.removed.equals(false),
  //           )
  //           ..orderBy([(b) => OrderingTerm.asc(b.page)]))
  //         .watch();
  //
  // Stream<List<BookmarkData>> watchSeriesBookmarks(int seriesId) =>
  //     (select(bookmarks)
  //           ..where(
  //             (b) => b.seriesId.equals(seriesId) & b.removed.equals(false),
  //           )
  //           ..orderBy([(b) => OrderingTerm.asc(b.page)]))
  //         .watch();

  Future<List<BookmarkData>> getDirtyBookmarks() =>
      (select(bookmarks)..where((b) => b.dirty.equals(true))).get();

  // Future<BookmarkData?> getByNaturalKey({
  //   required int chapterId,
  //   required int page,
  //   required String xPath,
  //   required int imageOffset,
  // }) {
  //   return (select(bookmarks)..where(
  //         (b) =>
  //             b.chapterId.equals(chapterId) &
  //             b.page.equals(page) &
  //             b.xPath.equals(xPath) &
  //             b.imageOffset.equals(imageOffset),
  //       ))
  //       .getSingleOrNull();
  // }
  //
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

  // Future<BookmarkData> upsertByNaturalKey(BookmarksCompanion entry) {
  //   return into(bookmarks).insertReturning(
  //     entry,
  //     onConflict: DoUpdate(
  //       (old) => entry,
  //       target: [
  //         bookmarks.chapterId,
  //         bookmarks.page,
  //         bookmarks.xPath,
  //         bookmarks.imageOffset,
  //       ],
  //     ),
  //   );
  // }
  //
  // /// Updates the row with [id], preserving its primary key. Used to rewrite
  // /// mutable metadata (e.g. [Bookmarks.xPath]) without creating a duplicate.
  // Future<BookmarkData> updateById(int id, BookmarksCompanion entry) async {
  //   final rows = await (update(
  //     bookmarks,
  //   )..where((b) => b.id.equals(id))).writeReturning(entry);
  //   return rows.single;
  // }

  /// Every locally stored, non-removed bookmark row, dirty and clean alike.
  /// Used to reconcile against the remote set during a full refresh.
  Future<List<BookmarkData>> getBookmarks() =>
      (select(bookmarks)..where((b) => b.removed.equals(false))).get();

  Future<void> markRemoved(int id) {
    return (update(bookmarks)..where((b) => b.id.equals(id))).write(
      const BookmarksCompanion(dirty: Value(true), removed: Value(true)),
    );
  }

  Future<void> deleteByIds(Iterable<int> ids) async {
    await (delete(bookmarks)..where((b) => b.id.isIn(ids))).go();
  }

  Future<void> clearDirtyFlags(Iterable<int> ids) async {
    await (update(bookmarks)..where((b) => b.id.isIn(ids))).write(
      const BookmarksCompanion(dirty: Value(false)),
    );
  }

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

  Future<List<int>> getExistingChapterIds() async {
    final q = selectOnly(chapters, distinct: true)..addColumns([chapters.id]);
    return q.map((row) => row.read(chapters.id)!).get();
  }

  //   Future<List<int>> getChapterIdsWithBookmarks({
  //     int? seriesId,
  //     int? volumeId,
  //   }) async {
  //     final q = selectOnly(bookmarks, distinct: true)
  //       ..addColumns([bookmarks.chapterId]);
  //     var condition = bookmarks.removed.equals(false);
  //     if (seriesId != null) {
  //       condition = condition & bookmarks.seriesId.equals(seriesId);
  //     }
  //     if (volumeId != null) {
  //       condition = condition & bookmarks.volumeId.equals(volumeId);
  //     }
  //     q.where(condition);
  //     return q.map((row) => row.read(bookmarks.chapterId)!).get();
  //   }
  //
  //   Stream<List<int>> watchChapterIdsWithBookmarks({
  //     int? seriesId,
  //     int? volumeId,
  //   }) {
  //     final q = selectOnly(bookmarks, distinct: true)
  //       ..addColumns([bookmarks.chapterId]);
  //     var condition = bookmarks.removed.equals(false);
  //     if (seriesId != null) {
  //       condition = condition & bookmarks.seriesId.equals(seriesId);
  //     }
  //     if (volumeId != null) {
  //       condition = condition & bookmarks.volumeId.equals(volumeId);
  //     }
  //     q.where(condition);
  //     return q.map((row) => row.read(bookmarks.chapterId)!).watch();
  //   }
  //
  //   /// Watch every series that has at least one non-removed bookmark, distinct
  //   /// and ordered by name.
  //   Stream<List<SeriesData>> watchBookmarkedSeries() {
  //     final q =
  //         select(series).join([
  //             innerJoin(bookmarks, bookmarks.seriesId.equalsExp(series.id)),
  //           ])
  //           ..where(bookmarks.removed.equals(false))
  //           ..groupBy([series.id])
  //           ..orderBy([OrderingTerm.asc(series.name)]);
  //
  //     return q.watch().map(
  //       (rows) => rows.map((row) => row.readTable(series)).toList(),
  //     );
  //   }
  //
  //   /// Watch every chapter that has at least one non-removed bookmark, distinct,
  //   /// optionally filtered by [seriesId] and [volumeId], ordered by sort order.
  //   Stream<List<Chapter>> watchBookmarkedChapters({
  //     int? seriesId,
  //     int? volumeId,
  //   }) {
  //     final q = select(chapters).join([
  //       innerJoin(bookmarks, bookmarks.chapterId.equalsExp(chapters.id)),
  //     ])..where(bookmarks.removed.equals(false));
  //
  //     if (seriesId != null) {
  //       q.where(chapters.seriesId.equals(seriesId));
  //     }
  //     if (volumeId != null) {
  //       q.where(chapters.volumeId.equals(volumeId));
  //     }
  //
  //     q
  //       ..groupBy([chapters.id])
  //       ..orderBy([OrderingTerm.asc(chapters.sortOrder)]);
  //
  //     return q.watch().map(
  //       (rows) => rows.map((row) => row.readTable(chapters)).toList(),
  //     );
  //   }
}
