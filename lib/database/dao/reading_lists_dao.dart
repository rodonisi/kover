import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/reading_lists.dart';

part 'reading_lists_dao.g.dart';

@DriftAccessor(
  tables: [
    ReadingLists,
    ReadingListsChapters,
    ReadingListCovers,
    ReadingProgress,
  ],
)
class ReadingListsDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingListsDaoMixin {
  ReadingListsDao(super.attachedDatabase);

  /// Get a single reading list by [readingListId].
  SingleSelectable<ReadingList> readingList(int readingListId) {
    return managers.readingLists.filter((f) => f.id.equals(readingListId));
  }

  /// Get all reading lists, ordered by title.
  Selectable<ReadingList> allReadingLists() {
    return managers.readingLists.orderBy((o) => o.title.asc());
  }

  /// Get all chapters for a reading list by [readingListId].
  Selectable<Chapter> readingListChapters({
    required int readingListId,
  }) {
    final q =
        select(readingListsChapters).join([
            innerJoin(
              chapters,
              chapters.id.equalsExp(readingListsChapters.chapterId),
            ),
          ])
          ..where(readingListsChapters.readingListId.equals(readingListId))
          ..orderBy([
            OrderingTerm(
              expression: readingListsChapters.order,
              mode: OrderingMode.asc,
            ),
            OrderingTerm(
              expression: chapters.sortOrder,
              mode: OrderingMode.asc,
            ),
            OrderingTerm(
              expression: chapters.title,
              mode: OrderingMode.asc,
            ),
          ]);

    return q.map((row) => row.readTable(chapters));
  }

  /// Get progress for a reading list by [readingListId].
  SingleSelectable<double> readingListProgress({
    required int readingListId,
  }) {
    final totalPagesSum = chapters.pages.sum();
    final totalPagesReadSum = readingProgress.pagesRead.sum();

    final progressExpression =
        (totalPagesReadSum.cast<double>() / totalPagesSum.cast<double>());

    final query =
        select(readingListsChapters).join([
            innerJoin(
              chapters,
              chapters.id.equalsExp(readingListsChapters.chapterId),
            ),
            leftOuterJoin(
              readingProgress,
              readingProgress.chapterId.equalsExp(chapters.id),
            ),
          ])
          ..where(readingListsChapters.readingListId.equals(readingListId))
          ..addColumns([
            progressExpression,
          ]);

    return query.map((row) {
      return row.read(progressExpression) ?? 0.0;
    });
  }

  /// Get the cover for a reading list by [readingListId].
  SingleOrNullSelectable<ReadingListCover> readingListCover({
    required int readingListId,
  }) {
    return managers.readingListCovers.filter(
      (f) => f.readingListId.id(readingListId),
    );
  }

  /// Upsert a batch of reading lists. Removes all entries not present in the batch.
  Future<void> upsertReadingListsBatch(
    Iterable<ReadingListsCompanion> entries,
  ) async {
    final ids = entries.map((e) => e.id.value).toList();
    final delta = await managers.readingLists
        .filter((f) => f.id.not.isIn(ids))
        .map((m) => m.id)
        .get();
    await transaction(() async {
      await (delete(readingLists)..where((t) => t.id.isIn(delta))).go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          readingLists,
          entries.toList(),
        );
      });
    });
  }

  /// Upsert a batch of reading list chapters.
  Future<void> upsertReadingListChaptersBatch(
    Iterable<ReadingListsChaptersCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        readingListsChapters,
        entries.toList(),
      );
    });
  }

  /// Upsert a batch of reading list covers.
  Future<void> upsertReadingListCoversBatch(
    Iterable<ReadingListCoversCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        readingListCovers,
        entries.toList(),
      );
    });
  }
}
