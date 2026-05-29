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

  /// Get [Selectable] for series in collection [collectionId]
  SingleOrNullSelectable<CollectionCover?> collectionCover({
    required int collectionId,
  }) {
    return managers.collectionCovers.filter(
      (f) => f.collectionId.id(collectionId),
    );
  }

  /// Get [Selectable] for all collections.
  Selectable<Collection> allCollections() {
    return managers.collections.orderBy((o) => o.title.asc());
  }

  /// Search collections by [query]
  Future<List<Collection>> searchCollections(String query) {
    return managers.collections
        .filter((f) => f.title.contains(query) | f.summary.contains(query))
        .orderBy((o) => o.title.asc())
        .get();
  }

  /// Get all collection ids missing covers.
  Future<List<int>> getMissingCovers() async {
    final query = select(collections).join([
      leftOuterJoin(
        collectionCovers,
        collectionCovers.collectionId.equalsExp(collections.id),
      ),
    ]);

    query.where(collectionCovers.collectionId.isNull());

    return await query.map((row) => row.readTable(collections).id).get();
  }

  /// Upsert a batch of collections.
  Future<void> upsertCollectionsBatch(
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
