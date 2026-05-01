import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/series_dto_mappings.dart';

class WantToReadSyncOperations {
  final Openapi _client;

  const WantToReadSyncOperations({required Openapi client}) : _client = client;

  /// Get the series in the want to read list
  Future<Iterable<SeriesCompanion>> getWantToReadList() async {
    final res = await _client.apiWantToReadV2Post(
      body: const SeriesFilterV2Dto(
        id: 0,
        limitTo: 0,
        combination: FilterCombination.and,
        sortOptions: SeriesSortOptionDto(
          sortField: SeriesSortField.sortname,
          isAscending: true,
        ),
        statements: [
          SeriesFilterStatementDto(
            comparison: FilterComparison.equal,
            field: SeriesFilterField.wanttoread,
            value: 'true',
          ),
        ],
      ),
    );
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load want-to-read list: ${res.error}');
    }
    return res.body!.map(
      (dto) => dto.toSeriesCompanion(),
    );
  }

  /// Add [seriesIds] to want-to-read
  Future<void> add(List<int> seriesIds) async {
    final res = await _client.apiWantToReadAddSeriesPost(
      body: UpdateWantToReadDto(seriesIds: seriesIds),
    );
    if (!res.isSuccessful) {
      throw Exception('Failed to add to want-to-read: ${res.error}');
    }
  }

  /// Remove [seriesIds] to want-to-read
  Future<void> remove(List<int> seriesIds) async {
    final res = await _client.apiWantToReadRemoveSeriesPost(
      body: UpdateWantToReadDto(seriesIds: seriesIds),
    );
    if (!res.isSuccessful) {
      throw Exception('Failed to remove from want-to-read: ${res.error}');
    }
  }
}
