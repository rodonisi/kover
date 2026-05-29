import 'package:kover/database/app_database.dart';
import 'package:kover/models/collection_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/collection_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collections_repository.g.dart';

@Riverpod(keepAlive: true)
CollectionsRepository collectionsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final client = CollectionSyncOperations(
    client: restClient,
    apiKey: apiKey!,
  );

  return CollectionsRepository(db: db, client: client);
}

class CollectionsRepository {
  final AppDatabase _db;
  final CollectionSyncOperations _client;

  CollectionsRepository({required this._db, required this._client});

  /// Watch all collections.
  Stream<List<CollectionModel>> watchCollections() {
    return _db.collectionsDao.allCollections().watch().map(
      (collections) =>
          collections.map(CollectionModel.fromDatabaseModel).toList(),
    );
  }

  /// Watch collection by [collectionId].
  Stream<CollectionModel> watchCollection(int collectionId) {
    return _db.collectionsDao
        .collection(collectionId)
        .watchSingle()
        .map(CollectionModel.fromDatabaseModel);
  }

  /// Watch collection cover by [collectionId]. Falls back to remote if not in database.
  Stream<ImageModel?> watchCollectionCover(int collectionId) {
    return _db.collectionsDao
        .collectionCover(collectionId: collectionId)
        .watchSingleOrNull()
        .asyncMap((cover) async {
          if (cover != null) {
            return ImageModel(data: cover.image);
          }

          try {
            final remoteCover = await _client.getCollectionCover(collectionId);
            if (remoteCover != null) {
              return ImageModel(data: remoteCover.image.value);
            }
          } catch (_) {
            return null;
          }

          return null;
        });
  }

  /// Refresh all collections.
  Future<void> refreshCollections() async {
    final collections = await _client.getCollections();

    await _db.collectionsDao.upsertCollectionsBatch(collections);

    for (var collection in collections) {
      final series = await _client.getCollectionSeries(collection.id.value);
      await _db.collectionsDao.upsertCollectionSeriesBatch(series);
    }
  }

  /// Fetch all covers for collections missing them.
  Future<void> fetchMissingCovers() async {
    final missingIds = await _db.collectionsDao.getMissingCovers();

    final covers = [
      for (var id in missingIds) await _client.getCollectionCover(id),
    ].whereType<CollectionCoversCompanion>();

    await _db.collectionsDao.upsertCollectionCoversBatch(covers);
  }
}
