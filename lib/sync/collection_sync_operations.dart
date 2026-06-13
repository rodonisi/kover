import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/collection_dto_mappings.dart';
import 'package:kover/utils/logging.dart';

class CollectionSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const CollectionSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Fetch all collections
  Future<Iterable<CollectionsCompanion>> getCollections() async {
    final res = await _client.apiCollectionGet();

    if (!res.isSuccessful) {
      throw Exception('Failed to fetch collections: ${res.error}');
    }

    return res.body?.map((collection) => collection.toCollectionsCompanion()) ??
        [];
  }

  /// Fetch all series in collection [collectionId]
  Future<Iterable<CollectionSeriesCompanion>> getCollectionSeries(
    int collectionId,
  ) async {
    final res = await _client.apiSeriesAllV2Post(
      context: .search,
      body: SeriesFilterV2Dto(
        id: 0,
        combination: .and,
        entityType: .series,
        limitTo: 0,
        sortOptions: const SeriesSortOptionDto(
          sortField: .createddate,
          isAscending: true,
        ),
        statements: [
          SeriesFilterStatementDto(
            comparison: .equal,
            field: .collectiontags,
            value: "$collectionId",
          ),
        ],
      ),
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to fetch collection series: ${res.error}');
    }

    return res.body?.map(
          (series) => CollectionSeriesCompanion(
            collectionId: Value(collectionId),
            seriesId: Value(series.id!),
          ),
        ) ??
        [];
  }

  /// Fetch collection cover for [collectionId]
  Future<CollectionCoversCompanion?> getCollectionCover(
    int collectionId,
  ) async {
    final res = await _client.apiImageCollectionCoverGet(
      collectionTagId: collectionId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      log.warning(
        'failed to download collection cover',
        attributes: {
          'collection_id': .int(collectionId),
          'status_code': .int(res.statusCode),
        },
      );
      return null;
    }

    return CollectionCoversCompanion(
      collectionId: Value(collectionId),
      image: Value(res.bodyBytes),
    );
  }
}
