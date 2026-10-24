import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/list_query_helpers.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/mapping/enums/sort_direction.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:rxdart/rxdart.dart';

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

  /// Watch a single reading list by [readingListId].
  Stream<ReadingList> watchReadingList(int readingListId) {
    return managers.readingLists
        .filter((f) => f.id.equals(readingListId))
        .watchSingleOrNull()
        .whereNotNull();
  }

  /// Get all reading lists, optionally filtered by [query] and ordered by
  /// [orderBy] in [direction].
  MultiSelectable<ReadingList> allReadingLists({
    String query = '',
    UnorderedSortOption orderBy = .name,
    SortDirection direction = .ascending,
  }) {
    final pagesReadSum = readingProgress.pagesRead.sum();
    final totalPages = chapters.pages.sum();
    final progress = progressRatio(pagesReadSum, totalPages);

    final q = select(readingLists).join([
      leftOuterJoin(
        readingListsChapters,
        readingListsChapters.readingListId.equalsExp(readingLists.id),
      ),
      leftOuterJoin(
        chapters,
        chapters.id.equalsExp(readingListsChapters.chapterId),
      ),
      leftOuterJoin(
        readingProgress,
        readingProgress.chapterId.equalsExp(chapters.id),
      ),
    ]);

    if (query.isNotEmpty) {
      q.where(
        matchesAllTokens(
          query,
          (token) =>
              containsAny(token, [readingLists.title, readingLists.summary]),
        ),
      );
    }

    q
      ..orderBy([
        OrderingTerm(
          expression: switch (orderBy) {
            .name => readingLists.title,
            .progress => progress,
            .lastRead => readingProgress.lastModified.max(),
            .dateAdded => readingLists.created,
            .dateUpdated => readingLists.lastModified,
          },
          mode: direction.toOrderingMode(),
        ),
      ])
      ..groupBy([readingLists.id]);

    return q.map((row) => row.readTable(readingLists));
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
