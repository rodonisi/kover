import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/list_query_helpers.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/collections.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/mapping/enums/sort_direction.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';

part 'collections_dao.g.dart';

@DriftAccessor(
  tables: [
    Collections,
    CollectionSeries,
    CollectionCovers,
    Chapters,
    Series,
    ReadingProgress,
  ],
)
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

  /// Get all collections, optionally filtered by [query] and ordered by
  /// [orderBy] in [direction].
  MultiSelectable<Collection> allCollections({
    String query = '',
    UnorderedSortOption orderBy = .name,
    SortDirection direction = .ascending,
  }) {
    final pagesReadSum = readingProgress.pagesRead.sum();
    final totalPages = chapters.pages.sum();
    final progress = progressRatio(pagesReadSum, totalPages);

    final q = select(collections).join([
      leftOuterJoin(
        collectionSeries,
        collectionSeries.collectionId.equalsExp(collections.id),
      ),
      leftOuterJoin(series, series.id.equalsExp(collectionSeries.seriesId)),
      leftOuterJoin(chapters, chapters.seriesId.equalsExp(series.id)),
      leftOuterJoin(
        readingProgress,
        readingProgress.chapterId.equalsExp(chapters.id),
      ),
    ]);

    if (query.isNotEmpty) {
      q.where(
        matchesAllTokens(
          query,
          (token) =>
              containsAny(token, [collections.title, collections.summary]),
        ),
      );
    }

    q
      ..orderBy([
        OrderingTerm(
          expression: switch (orderBy) {
            .name => collections.title,
            .progress => progress,
            .lastRead => readingProgress.lastModified.max(),
            .dateAdded => collections.created,
            .dateUpdated => collections.lastModified,
          },
          mode: direction.toOrderingMode(),
        ),
      ])
      ..groupBy([collections.id]);

    return q.map((row) => row.readTable(collections));
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

  /// Upsert a batch of collections. Deletes any collections not in the batch.
  Future<void> upsertCollectionsBatch(
    Iterable<CollectionsCompanion> entries,
  ) async {
    final ids = entries.map((e) => e.id.value).toList();
    final delta = await managers.collections
        .filter((f) => f.id.not.isIn(ids))
        .map((m) => m.id)
        .get();
    await transaction(() async {
      await (delete(collections)..where((t) => t.id.isIn(delta))).go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          collections,
          entries.toList(),
        );
      });
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
