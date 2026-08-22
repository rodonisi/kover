import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/smart_filter_dto_mappings.dart';

class SmartFiltersSyncOperations {
  final Openapi _client;

  const new({required this._client});

  /// Fetch all smart filters.
  Future<Iterable<SmartFiltersCompanion>> getSmartFilters() async {
    final res = await _client.apiFilterGet();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load smart filters: ${res.error}');
    }

    return res.body!.map((dto) => dto.toSmartFiltersCompanion());
  }

  /// Fetches the ids of all entities matching [smartFilter]'s decoded filter.
  Future<Iterable<int>> getEntityIds(SmartFiltersCompanion smartFilter) async {
    final encodedFilter = smartFilter.filter.value;
    if (encodedFilter == null) return const [];

    final filterResponse = await _client.apiFilterDecodePost(
      body: DecodeFilterDto(encodedFilter: encodedFilter),
    );

    if (!filterResponse.isSuccessful || filterResponse.body == null) {
      throw Exception(
        'Failed to decode smart filter: ${filterResponse.error}',
      );
    }

    final json = jsonDecode(filterResponse.bodyString) as Map<String, dynamic>;

    switch (smartFilter.type.value) {
      case .series:
        final res = await _client.apiSeriesAllV2Post(
          body: SeriesFilterV2Dto.fromJson(json),
        );
        return _ids(res, 'series', (series) => series.id!);
      case .readingList:
        final res = await _client.apiReadingListAllPost(
          body: ReadingListFilterDto.fromJson(json),
        );
        return _ids(res, 'reading lists', (readingList) => readingList.id!);
      case .person:
        final res = await _client.apiPersonAllPost(
          body: PersonFilterDto.fromJson(json),
        );
        return _ids(res, 'people', (person) => person.id!);
      case .annotation || .unknown:
        return const [];
    }
  }

  Iterable<int> _ids<T>(
    Response<List<T>> res,
    String what,
    int Function(T) idOf,
  ) {
    if (!res.isSuccessful) {
      throw Exception('Failed to fetch $what for smart filter: ${res.error}');
    }

    return res.body?.map(idOf) ?? const [];
  }
}
