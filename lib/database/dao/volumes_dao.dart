import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/database/dao/list_query_helpers.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/mapping/enums/sort_direction.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';

part 'volumes_dao.g.dart';

@DriftAccessor(
  tables: [
    Volumes,
    VolumeCovers,
    Chapters,
    ReadingProgress,
    Series,
    Libraries,
  ],
)
class VolumesDao extends DatabaseAccessor<AppDatabase> with _$VolumesDaoMixin {
  VolumesDao(super.attachedDatabase);

  /// Get a [SingleOrNullSelectable] for volume [volumeId] with its chapters
  SingleOrNullSelectable<VolumeWithRelations> volume(int volumeId) {
    return managers.volumes
        .withReferences(
          (prefetch) => prefetch(chaptersRefs: true),
        )
        .filter((f) => f.id(volumeId))
        .map((result) {
          final (vol, refs) = result;
          final chapters = refs.chaptersRefs.prefetchedData ?? [];

          chapters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          return VolumeWithRelations(volume: vol, chapters: chapters);
        });
  }

  /// Search volumes by [query]. Optionally filter by [seriesId]
  Future<List<Volume>> searchVolumes(
    String query, {
    int? seriesId,
  }) async {
    final q = managers.volumes
        .filter((f) => f.seriesId.libraryId.includeInSearch(true))
        .filter((f) => f.name.contains(query));

    if (seriesId != null) {
      q.filter((f) => f.seriesId.id(seriesId));
    }

    q.orderBy((o) => o.minNumber.asc() & o.name.asc());

    return await q.get();
  }

  /// Watch pages read for volume [volumeId]
  Stream<int?> watchPagesRead({required int volumeId}) {
    final pagesReadSum = readingProgress.pagesRead.sum();

    final query = selectOnly(readingProgress)
      ..addColumns([pagesReadSum])
      ..where(readingProgress.volumeId.equals(volumeId))
      ..groupBy([readingProgress.volumeId]);

    return query.watchSingleOrNull().map((row) => row?.read(pagesReadSum));
  }

  /// Watch volumes for series [seriesId], optionally filtering by [query]
  /// (volume name) and excluding fully read volumes when [hideRead] is true.
  MultiSelectable<Volume> watchVolumes({
    required int seriesId,
    bool hideRead = false,
    String query = '',
    OrderedSortOption orderBy = .sortOrder,
    SortDirection direction = .ascending,
  }) {
    final pagesReadSum = readingProgress.pagesRead.sum();
    final totalPages = chapters.pages.sum();
    final progress = progressRatio(pagesReadSum, totalPages);

    final q = select(volumes).join([
      leftOuterJoin(chapters, chapters.volumeId.equalsExp(volumes.id)),
      leftOuterJoin(
        readingProgress,
        readingProgress.chapterId.equalsExp(chapters.id),
      ),
    ]);

    q.where(volumes.seriesId.equals(seriesId));

    if (query.isNotEmpty) {
      q.where(containsAny(query, [volumes.name]));
    }

    q
      ..orderBy([
        OrderingTerm(
          expression: switch (orderBy) {
            .sortOrder => volumes.minNumber,
            .name => volumes.name,
            .progress => progress,
            .lastRead => readingProgress.lastModified.max(),
            .dateAdded => volumes.created,
            .dateUpdated => volumes.lastModified,
          },
          mode: direction.toOrderingMode(),
        ),
      ])
      ..groupBy(
        [volumes.id],
        having: hideRead ? hasUnreadProgress(pagesReadSum, totalPages) : null,
      );

    return q.map((row) => row.readTable(volumes));
  }

  /// Get [SingleOrNullSelectable] cover for volume [volumeId]. If no cover is present, returns null.
  SingleOrNullSelectable<VolumeCover?> volumeCover({required int volumeId}) {
    return managers.volumeCovers.filter((f) => f.volumeId.id(volumeId));
  }

  /// Get all volume ids missing a cover
  Future<List<int>> getMissingCovers() async {
    final query = select(volumes).join([
      leftOuterJoin(volumeCovers, volumeCovers.volumeId.equalsExp(volumes.id)),
    ]);

    query.where(volumeCovers.volumeId.isNull());

    return await query.map((row) => row.readTable(volumes).id).get();
  }

  /// Upsert a volume cover
  Future<void> upsertVolumeCover(VolumeCoversCompanion cover) async {
    await into(volumeCovers).insertOnConflictUpdate(cover);
  }

  /// Upsert multiple volume covers in a single batch to avoid per-insert
  /// [notifyUpdates] cascades that can block the main thread.
  Future<void> upsertVolumeCoversBatch(
    Iterable<VolumeCoversCompanion> covers,
  ) async {
    if (covers.isEmpty) return;

    await batch((b) => b.insertAllOnConflictUpdate(volumeCovers, covers));
  }
}

class VolumeWithRelations {
  final Volume volume;
  final List<Chapter> chapters;

  const VolumeWithRelations({required this.volume, required this.chapters});
}

class const VolumeWithChaptersCompanion({
  required final VolumesCompanion volume,
  required final Iterable<ChapterWithRelationsCompanion> chapters,
});
