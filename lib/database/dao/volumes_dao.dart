import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/volumes.dart';

part 'volumes_dao.g.dart';

@DriftAccessor(tables: [Volumes, VolumeCovers, Chapters, ReadingProgress])
class VolumesDao extends DatabaseAccessor<AppDatabase> with _$VolumesDaoMixin {
  VolumesDao(super.attachedDatabase);

  /// Get a [SingleSelectable] for volume [volumeId]
  SingleSelectable<VolumeWithRelations> volume(int volumeId) {
    return managers.volumes
        .withReferences(
          (prefetch) => prefetch(chaptersRefs: true),
        )
        .filter((f) => f.id(volumeId))
        .map((result) {
          final (vol, refs) = result;
          return VolumeWithRelations(
            volume: vol,
            chapters: refs.chaptersRefs.prefetchedData ?? [],
          );
        });
  }

  /// Search volumes by [query]. Optionally filter by [seriesId]
  Future<List<VolumeWithRelations>> searchVolumes(
    String query, {
    int? seriesId,
  }) async {
    final q = managers.volumes
        .withReferences(
          (prefetch) => prefetch(chaptersRefs: true),
        )
        .filter((f) => f.name.contains(query));

    if (seriesId != null) {
      q.filter((f) => f.seriesId.id(seriesId));
    }

    q.orderBy((o) => o.minNumber.asc() & o.name.asc());

    return await q.map((result) {
      final (vol, refs) = result;
      return VolumeWithRelations(
        volume: vol,
        chapters: refs.chaptersRefs.prefetchedData ?? [],
      );
    }).get();
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
}

class VolumeWithRelations {
  final Volume volume;
  final List<Chapter> chapters;

  const VolumeWithRelations({required this.volume, required this.chapters});
}

class VolumeWithChaptersCompanion {
  final VolumesCompanion volume;
  final Iterable<ChaptersCompanion> chapters;

  const VolumeWithChaptersCompanion({
    required this.volume,
    this.chapters = const [],
  });
}
