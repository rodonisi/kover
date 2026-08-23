import 'package:kover/database/app_database.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/smart_filter_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/smart_filters_sync_operations.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'smart_filters_repository.g.dart';

@Riverpod(keepAlive: true)
SmartFiltersRepository smartFiltersRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  return SmartFiltersRepository(
    db: db,
    client: SmartFiltersSyncOperations(client: restClient),
  );
}

class const SmartFiltersRepository({
  required final AppDatabase _db,
  required final SmartFiltersSyncOperations _client,
}) {
  Stream<SmartFilterModel> watchSmartFilter(int id) {
    return _db.smartFiltersDao
        .watchSmartFilter(id)
        .map(SmartFilterModel.fromDatabaseModel)
        .distinct();
  }

  /// Watch the series linked to [smartFilterId].
  Stream<List<SeriesModel>> watchSeries(int smartFilterId) {
    return _db.smartFiltersDao
        .watchSeriesForSmartFilter(smartFilterId)
        .map(
          (series) => series.map(SeriesModel.fromDatabaseModel).toList(),
        );
  }

  /// Watch the reading lists linked to [smartFilterId].
  Stream<List<ReadingListModel>> watchReadingLists(int smartFilterId) {
    return _db.smartFiltersDao
        .watchReadingListsForSmartFilter(smartFilterId)
        .map(
          (readingLists) =>
              readingLists.map(ReadingListModel.fromDatabaseModel).toList(),
        );
  }

  /// Syncs all smart filters and their linked entities from the server.
  /// Smart filters and links not present on the server anymore are removed.
  Future<void> syncSmartFilters() async {
    final smartFilters = await _client.getSmartFilters();
    await _db.smartFiltersDao.upsertSmartFilterBatch(smartFilters);

    await chunkedFetch<
      SmartFiltersCompanion,
      (SmartFiltersCompanion, Iterable<int>)?
    >(
      items: smartFilters,
      fetchCallback: (smartFilter) async {
        try {
          return (smartFilter, await _client.getEntityIds(smartFilter));
        } catch (e) {
          log.warning(
            'failed to fetch entities for smart filter',
            attributes: {
              'smart_filter_id': smartFilter.id.value,
              'error_type': e.runtimeType,
            },
          );
          return null;
        }
      },
      upsertCallback: (batch) async {
        final fetched = batch
            .whereType<(SmartFiltersCompanion, Iterable<int>)>();

        for (final (smartFilter, ids) in fetched) {
          if (ids.isEmpty) {
            await _db.smartFiltersDao.deleteSmartFilterLinks(
              smartFilter.id.value,
            );
            continue;
          }

          switch (smartFilter.type.value) {
            case .series:
              await _db.smartFiltersDao.upsertSmartFilterSeriesBatch(
                ids.map(
                  (id) => SmartFilterSeriesCompanion.insert(
                    smartFilterId: smartFilter.id.value,
                    seriesId: id,
                  ),
                ),
              );
            case .readingList:
              await _db.smartFiltersDao.upsertSmartFilterReadingListBatch(
                ids.map(
                  (id) => SmartFilterReadingListCompanion.insert(
                    smartFilterId: smartFilter.id.value,
                    readingListId: id,
                  ),
                ),
              );
            case .person:
              await _db.smartFiltersDao.upsertSmartFilterPersonBatch(
                ids.map(
                  (id) => SmartFilterPersonCompanion.insert(
                    smartFilterId: smartFilter.id.value,
                    personId: id,
                  ),
                ),
              );
            case .annotation || .unknown:
              break;
          }
        }
      },
    );
  }
}
