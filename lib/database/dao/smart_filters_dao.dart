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
  Future<void> upsertSmartFilterBatch(
    Iterable<SmartFiltersCompanion> b,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(smartFilters, b);
    });
  }
}
