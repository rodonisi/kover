import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/mapping/dto/chapter_dto_mappings.dart';
import 'package:kover/mapping/dto/series_dto_mappings.dart';
import 'package:kover/mapping/dto/series_metadata_dto_mappings.dart';
import 'package:kover/mapping/dto/volume_dto_mappings.dart';
import 'package:kover/utils/extensions/date_time.dart';

class SeriesSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const SeriesSyncOperations({
    required Openapi client,
    required String apiKey,
  }) : _client = client,
       _apiKey = apiKey;

  Future<Iterable<SeriesCompanion>> getAllSeries({int? libraryId}) async {
    final res = await _fetchAllSeries(libraryId: libraryId);

    return res.map((dto) => dto.toSeriesCompanion());
  }

  Future<Map<int, DateTime>> getLastReadForSeries() async {
    final res = await _fetchAllSeries();

    return Map.fromEntries(
      res
          .where((entry) => entry.id != null && entry.latestReadDate != null)
          .map(
            (entry) =>
                MapEntry(entry.id!, entry.latestReadDate!.normalizeUtc()),
          ),

    );
  }

  Future<Iterable<SeriesCompanion>> getRecentlyAdded() async {
    final res = await _client.apiSeriesRecentlyAddedV2Post(
      body: FilterV2Dto(
        id: 0,
        combination: FilterV2DtoCombination.value_0.value,
        sortOptions: SortOptions(
          sortField: SortOptionsSortField.value_1.value,
          isAscending: false,
        ),
        limitTo: 0,
        statements: [],
      ),
    );

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load recently added: ${res.error}');
    }

    return res.body!.map(
      (dto) =>
          dto.toSeriesCompanion().copyWith(isRecentlyAdded: const Value(true)),
    );
  }

  Future<Iterable<SeriesCompanion>> getRecentlyUpdated() async {
    final res = await _client.apiSeriesRecentlyUpdatedSeriesPost();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load recently updated: ${res.error}');
    }

    return Future.wait(
      res.body!.map(
        (entry) async {
          final series = await getSeries(entry.seriesId!);
          return series.copyWith(isRecentlyUpdated: const Value(true));
        },
      ),
    );
  }

  Future<SeriesCompanion> getSeries(int seriesId) async {
    final res = await _client.apiSeriesSeriesIdGet(seriesId: seriesId);

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load series: ${res.error}');
    }

    return res.body!.toSeriesCompanion();
  }

  Future<SeriesCoversCompanion> getSeriesCover(int seriesId) async {
    final res = await _client.apiImageSeriesCoverGet(
      seriesId: seriesId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to load series cover: ${res.error}');
    }

    return SeriesCoversCompanion(
      seriesId: Value(seriesId),
      image: Value(res.bodyBytes),
    );
  }

  /// Get series metadata for [seriesId]
  Future<SeriesMetadataCompanions> getSeriesMetadata(int seriesId) async {
    final res = await _client.apiSeriesMetadataGet(seriesId: seriesId);

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load series metadata: ${res.error}');
    }

    final dto = res.body!;

    return dto.toSeriesMetadataCompanions();
  }

  Future<SeriesDetailCompanions> getSeriesDetail(
    int seriesId,
  ) async {
    final res = await _client.apiSeriesSeriesDetailGet(seriesId: seriesId);

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load series detail: ${res.error}');
    }

    final dto = res.body!;

    final storyline = (dto.storylineChapters ?? []).map(
      (c) => c.toChapterCompanion().copyWith(
        seriesId: Value(seriesId),
        isStoryline: const Value(true),
      ),
    );
    final specials = (dto.specials ?? []).map(
      (c) => c.toChapterCompanion().copyWith(
        seriesId: Value(seriesId),
        isSpecial: const Value(true),
      ),
    );
    final chapters = (dto.chapters ?? []).map(
      (c) => c.toChapterCompanion().copyWith(
        seriesId: Value(seriesId),
      ),
    );
    final volumes = (dto.volumes ?? []).map(
      (v) => v.toVolumeCompanion(),
    );

    final allChapters = <ChapterDto>{
      ...dto.chapters ?? [],
      ...dto.specials ?? [],
      ...dto.storylineChapters ?? [],
      ...dto.volumes?.map((v) => v.chapters).expand((l) => l ?? []) ?? [],
    };

    final progress = allChapters.map(
      (c) => c.toPartialReadingProgressCompanion(),
    );

    return SeriesDetailCompanions(
      seriesId: seriesId,
      storyline: storyline,
      specials: specials,
      chapters: chapters,
      volumes: volumes,
      progress: progress,
    );
  }

  Future<List<SeriesDto>> _fetchAllSeries({int? libraryId}) async {
    final res = await _client.apiSeriesV2Post(
      body: FilterV2Dto(
        id: 0,
        combination: FilterV2DtoCombination.value_0.value,
        sortOptions: SortOptions(
          sortField: SortOptionsSortField.value_1.value,
          isAscending: false,
        ),
        limitTo: 0,
        statements: [
          if (libraryId != null)
            FilterStatementDto(
              comparison: FilterStatementDtoComparison.value_0.value,
              field: FilterStatementDtoField.value_19.value,
              value: libraryId.toString(),
            ),
        ],
      ),
    );

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load series: ${res.error}');
    }
    return res.body!;
  }
}
