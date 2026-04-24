import 'package:kover/database/app_database.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'volumes_repository.g.dart';

@Riverpod(keepAlive: true)
VolumesRepository volumesRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final client = VolumeSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );
  return VolumesRepository(db, client);
}

class VolumesRepository {
  final AppDatabase _db;
  final VolumeSyncOperations _client;

  VolumesRepository(this._db, this._client);

  /// Watch volume [volumeId]
  Stream<VolumeModel> watchVolume(int volumeId) {
    return _db.volumesDao
        .volume(volumeId)
        .watchSingle()
        .map(VolumeModel.fromDatabaseModel);
  }

  /// Search volumes by [query]. Optionally filter by [seriesId]
  Future<List<VolumeModel>> searchVolumes(
    String query, {
    int? seriesId,
  }) async {
    if (query.isEmpty) return [];

    final results = await _db.volumesDao.searchVolumes(
      query,
      seriesId: seriesId,
    );

    return results.map(VolumeModel.fromDatabaseModel).toList();
  }

  /// Watch total number of pages read for volume [volumeId]
  Stream<int> watchPagesRead({required int volumeId}) {
    return _db.volumesDao.watchPagesRead(volumeId: volumeId).map((n) => n ?? 0);
  }

  /// Watch cover for volume [volumeId]
  Stream<ImageModel?> watchVolumeCover(int volumeId) {
    return _db.volumesDao
        .watchVolumeCover(volumeId: volumeId)
        .map((cover) => cover != null ? ImageModel(data: cover.image) : null);
  }

  Future<List<int>> getChapterIds({required int volumeId}) async {
    final volume = await _db.volumesDao.volume(volumeId).getSingle();

    return volume.chapters.map((c) => c.id).toList();
  }

  /// Fetch missing covers for all volumes
  Future<void> fetchMissingCovers() async {
    final missing = await _db.volumesDao.getMissingCovers();
    for (final id in missing) {
      final volumeCover = await _client.getVolumeCover(id);

      if (volumeCover == null) continue;

      await _db.volumesDao.upsertVolumeCover(volumeCover);
    }
  }
}
