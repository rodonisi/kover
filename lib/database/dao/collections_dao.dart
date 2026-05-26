import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/collections.dart';

part 'collections_dao.g.dart';

@DriftAccessor(tables: [Collections, CollectionSeries, CollectionCovers])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.attachedDatabase);

  /// Get [SingleSelectable] for collection [collectionId]
  SingleSelectable<Collection> collection(int collectionId) {
    return managers.collections.filter((f) => f.id.equals(collectionId));
  }

  /// Search collections by [query]
  Future<List<Collection>> searchCollections(String query) {
    return managers.collections
        .filter((f) => f.title.contains(query) | f.summary.contains(query))
        .orderBy((o) => o.title.asc())
        .get();
  }

  /// Upsert a batch of collections.
  Future<void> upsertCollectionBatch(
    Iterable<CollectionsCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        collections,
        entries.toList(),
      );
    });
  }

  /// Upsert a batch of collection-series relations.
  Future<void> upsertCollectionSeriesBatch(
    Iterable<CollectionSeriesCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        collectionSeries,
        entries.toList(),
      );
    });
  }

  /// Upsert a batch of collection covers.
  Future<void> upsertCollectionCoversBatch(
    Iterable<CollectionCoversCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        collectionCovers,
        entries.toList(),
      );
    });
  }
}
