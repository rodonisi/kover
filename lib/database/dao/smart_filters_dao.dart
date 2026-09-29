import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/list_query_helpers.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/download.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/database/tables/smart_filters.dart';
import 'package:kover/mapping/enums/sort_direction.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:rxdart/rxdart.dart';

part 'smart_filters_dao.g.dart';

@DriftAccessor(
  tables: [
    Series,
    ReadingLists,
    ReadingListsChapters,
    Chapters,
    People,
    SmartFilters,
    SmartFilterSeries,
    SmartFilterReadingList,
    SmartFilterPerson,
    ReadingProgress,
    DownloadedPages,
  ],
)
class SmartFiltersDao(super.attachedDatabase)
    extends DatabaseAccessor<AppDatabase>
    with _$SmartFiltersDaoMixin {
  Expression<bool> get _hasUnreadProgress =>
      hasUnreadProgress(readingProgress.pagesRead.sum(), series.pages);

  /// Whether series has at least one page stored locally.
  Expression<bool> get _hasDownloads => series.id.isInQuery(
    selectOnly(chapters)
      ..addColumns([chapters.seriesId])
      ..join([
        innerJoin(
          downloadedPages,
          downloadedPages.chapterId.equalsExp(chapters.id),
        ),
      ]),
  );

  Expression<double> get _progressRatio =>
      progressRatio(readingProgress.pagesRead.sum(), series.pages);

  OrderingTerm _orderingTerm(UnorderedSortOption column, OrderingMode mode) {
    return switch (column) {
      .name => OrderingTerm(
        expression: series.sortName,
        mode: mode,
      ),
      .progress => OrderingTerm(
        expression: _progressRatio,
        mode: mode,
      ),
      .lastRead => OrderingTerm(
        expression: readingProgress.lastModified.max(),
        mode: mode,
      ),
      .dateAdded => OrderingTerm(
        expression: series.created,
        mode: mode,
      ),
      .dateUpdated => OrderingTerm(
        expression: series.lastChapterAdded,
        mode: mode,
      ),
    };
  }

  /// Watches a specific smart filter by its [id].
  Stream<SmartFilter> watchSmartFilter(int id) {
    return (select(
      smartFilters,
    )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull().whereNotNull();
  }

  /// Watches the list of series associated with a specific smart filter.
  Stream<List<SeriesData>> watchSeriesForSmartFilter(
    int smartFilterId, {
    String query = '',
    UnorderedSortOption orderBy = .name,
    SortDirection direction = .ascending,
    bool hideRead = false,
    bool downloadedOnly = false,
  }) {
    final q =
        select(series).join([
            innerJoin(
              smartFilterSeries,
              smartFilterSeries.seriesId.equalsExp(series.id),
            ),
            leftOuterJoin(
              readingProgress,
              readingProgress.seriesId.equalsExp(series.id),
            ),
          ])
          ..where(smartFilterSeries.smartFilterId.equals(smartFilterId))
          ..groupBy(
            [series.id],
            having: hideRead ? _hasUnreadProgress : null,
          );

    if (query.isNotEmpty) {
      q.where(
        containsAny(
          query,
          [
            series.name,
            series.sortName,
            series.localizedName,
            series.originalName,
          ],
        ),
      );
    }

    if (downloadedOnly) {
      q.where(_hasDownloads);
    }

    q.orderBy([_orderingTerm(orderBy, direction.toOrderingMode())]);

    return q.map((row) => row.readTable(series)).watch();
  }

  /// Watches the list of reading lists associated with a specific smart
  /// filter, optionally filtered by [query] and ordered by [orderBy] in
  /// [direction].
  Stream<List<ReadingList>> watchReadingListsForSmartFilter(
    int smartFilterId, {
    String query = '',
    UnorderedSortOption orderBy = .name,
    SortDirection direction = .ascending,
  }) {
    final pagesReadSum = readingProgress.pagesRead.sum();
    final totalPages = chapters.pages.sum();
    final progress = progressRatio(pagesReadSum, totalPages);

    final q = select(readingLists).join([
      innerJoin(
        smartFilterReadingList,
        smartFilterReadingList.readingListId.equalsExp(readingLists.id),
      ),
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
    ])..where(smartFilterReadingList.smartFilterId.equals(smartFilterId));

    if (query.isNotEmpty) {
      q.where(containsAny(query, [readingLists.title, readingLists.summary]));
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

    return q.watch().map(
      (results) => results.map((row) => row.readTable(readingLists)).toList(),
    );
  }

  /// Upserts a batch of smart filters into the database.
  /// Smart filters not present in the batch will be removed from the database.
  Future<void> upsertSmartFilterBatch(
    Iterable<SmartFiltersCompanion> b,
  ) async {
    final ids = b.map((e) => e.id.value).toList();

    await batch((batch) {
      batch.deleteWhere(smartFilters, (t) => t.id.isNotIn(ids));
      batch.insertAllOnConflictUpdate(smartFilters, b);
    });
  }

  /// Upserts a batch of smart filter series into the database.
  /// Series links not present in the batch will be removed from the database.
  Future<void> upsertSmartFilterSeriesBatch(
    Iterable<SmartFilterSeriesCompanion> b,
  ) async {
    final idsByFilter = <int, List<int>>{};
    for (final link in b) {
      idsByFilter
          .putIfAbsent(link.smartFilterId.value, () => [])
          .add(link.seriesId.value);
    }

    await batch((batch) {
      for (final entry in idsByFilter.entries) {
        final seriesIds = entry.value;
        batch.deleteWhere(
          smartFilterSeries,
          (t) =>
              t.smartFilterId.equals(entry.key) & t.seriesId.isNotIn(seriesIds),
        );
      }
      batch.insertAllOnConflictUpdate(smartFilterSeries, b);
    });
  }

  /// Upserts a batch of smart filter reading lists into the database.
  /// Reading list links not present in the batch will be removed from the
  /// database.
  Future<void> upsertSmartFilterReadingListBatch(
    Iterable<SmartFilterReadingListCompanion> b,
  ) async {
    final idsByFilter = <int, List<int>>{};
    for (final link in b) {
      idsByFilter
          .putIfAbsent(
            link.smartFilterId.value,
            () => [],
          )
          .add(link.readingListId.value);
    }

    await batch((batch) {
      for (final entry in idsByFilter.entries) {
        final readingListIds = entry.value;
        batch.deleteWhere(
          smartFilterReadingList,
          (t) =>
              t.smartFilterId.equals(entry.key) &
              t.readingListId.isNotIn(readingListIds),
        );
      }
      batch.insertAllOnConflictUpdate(smartFilterReadingList, b);
    });
  }

  /// Upserts a batch of smart filter people into the database.
  /// People links not present in the batch will be removed from the database.
  Future<void> upsertSmartFilterPersonBatch(
    Iterable<SmartFilterPersonCompanion> b,
  ) async {
    final idsByFilter = <int, List<int>>{};
    for (final link in b) {
      idsByFilter
          .putIfAbsent(
            link.smartFilterId.value,
            () => [],
          )
          .add(link.personId.value);
    }

    await batch((batch) {
      for (final entry in idsByFilter.entries) {
        final personIds = entry.value;
        batch.deleteWhere(
          smartFilterPerson,
          (t) =>
              t.smartFilterId.equals(entry.key) & t.personId.isNotIn(personIds),
        );
      }
      batch.insertAllOnConflictUpdate(smartFilterPerson, b);
    });
  }

  /// Removes all stored series, reading list and people links for
  /// [smartFilterId].
  Future<void> deleteSmartFilterLinks(int smartFilterId) async {
    await batch((batch) {
      batch.deleteWhere(
        smartFilterSeries,
        (t) => t.smartFilterId.equals(smartFilterId),
      );
      batch.deleteWhere(
        smartFilterReadingList,
        (t) => t.smartFilterId.equals(smartFilterId),
      );
      batch.deleteWhere(
        smartFilterPerson,
        (t) => t.smartFilterId.equals(smartFilterId),
      );
    });
  }
}
