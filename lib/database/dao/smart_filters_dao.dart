import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/database/tables/smart_filters.dart';

part 'smart_filters_dao.g.dart';

@DriftAccessor(
  tables: [
    Series,
    ReadingLists,
    People,
    SmartFilters,
    SmartFilterSeries,
    SmartFilterReadingList,
    SmartFilterPerson,
  ],
)
class SmartFiltersDao(super.attachedDatabase)
    extends DatabaseAccessor<AppDatabase>
    with _$SmartFiltersDaoMixin {
  /// Retrieves a list of series associated with a specific smart filter.
  Future<List<SeriesData>> getSeriesForSmartFilter(int smartFilterId) async {
    final query = select(series).join([
      innerJoin(
        smartFilterSeries,
        smartFilterSeries.seriesId.equalsExp(series.id),
      ),
    ])..where(smartFilterSeries.smartFilterId.equals(smartFilterId));

    final results = await query.get();

    return results.map((row) => row.readTable(series)).toList();
  }

  /// Retrieves a list of reading lists associated with a specific smart filter.
  Future<List<ReadingList>> getReadingListsForSmartFilter(
    int smartFilterId,
  ) async {
    final query = select(readingLists).join([
      innerJoin(
        smartFilterReadingList,
        smartFilterReadingList.readingListId.equalsExp(readingLists.id),
      ),
    ])..where(smartFilterReadingList.smartFilterId.equals(smartFilterId));

    final results = await query.get();

    return results.map((row) => row.readTable(readingLists)).toList();
  }

  /// Retrieves a list of people associated with a specific smart filter.
  Future<List<PeopleData>> getPeopleForSmartFilter(int smartFilterId) async {
    final query = select(people).join([
      innerJoin(
        smartFilterPerson,
        smartFilterPerson.personId.equalsExp(people.id),
      ),
    ])..where(smartFilterPerson.smartFilterId.equals(smartFilterId));

    final results = await query.get();

    return results.map((row) => row.readTable(people)).toList();
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
      idsByFilter.putIfAbsent(link.smartFilterId.value, () => []).add(link.seriesId.value);
    }

    await batch((batch) {
      for (final entry in idsByFilter.entries) {
        final seriesIds = entry.value;
        batch.deleteWhere(
          smartFilterSeries,
          (t) => t.smartFilterId.equals(entry.key) & t.seriesId.isNotIn(seriesIds),
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
      idsByFilter.putIfAbsent(
        link.smartFilterId.value,
        () => [],
      ).add(link.readingListId.value);
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
      idsByFilter.putIfAbsent(
        link.smartFilterId.value,
        () => [],
      ).add(link.personId.value);
    }

    await batch((batch) {
      for (final entry in idsByFilter.entries) {
        final personIds = entry.value;
        batch.deleteWhere(
          smartFilterPerson,
          (t) => t.smartFilterId.equals(entry.key) & t.personId.isNotIn(personIds),
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
