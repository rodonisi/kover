import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/collection_dto_mappings.dart';

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
}
