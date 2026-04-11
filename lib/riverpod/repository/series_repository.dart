import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'series_repository.g.dart';

@Riverpod(keepAlive: true)
SeriesRepository seriesRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final client = SeriesSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );
  final volumeClient = VolumeSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );
  final chapterClient = ChapterSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );
  return SeriesRepository(
    db: db,
    client: client,
    volumeClient: volumeClient,
    chapterClient: chapterClient,
  );
}

class SeriesRepository {
  final AppDatabase _db;
  final SeriesSyncOperations _client;
  final VolumeSyncOperations _volumeClient;
  final ChapterSyncOperations _chapterClient;

  const SeriesRepository({
    required AppDatabase db,
    required SeriesSyncOperations client,
    required VolumeSyncOperations volumeClient,
    required ChapterSyncOperations chapterClient,
  }) : _db = db,
       _client = client,
       _volumeClient = volumeClient,
       _chapterClient = chapterClient;

  /// Watch series [seriesId]
  Stream<SeriesModel> watchSeries(int seriesId) {
    return _db.seriesDao
        .watchSeries(seriesId)
        .map(SeriesModel.fromDatabaseModel);
  }

  Future<List<int>> allChapterIds({required int seriesId}) async {
    final chapters = await _db.seriesDao.allChapters(seriesId: seriesId).get();

    return chapters.map((c) => c.id).toList();
  }

  Stream<SeriesModel> watchSeriesForChapter(int chapterId) {
    return _db.seriesDao
        .watchSeriesForChapter(chapterId)
        .map(SeriesModel.fromDatabaseModel);
  }

  /// Watch [SeriesMetadataModel] for series [seriesId]
  Stream<SeriesMetadataModel> watchSeriesMetadata(int seriesId) {
    return _db.seriesMetadataDao
        .watchSeriesMetadata(seriesId)
        .map(SeriesMetadataModel.fromDatabaseModel);
  }

  /// Watch total number of pages read for series [seriesId]
  Stream<int> watchPagesRead({required int seriesId}) {
    return _db.seriesDao.watchPagesRead(seriesId: seriesId).map((n) => n ?? 0);
  }

  /// Watch series cover for series [seriesId]
  Stream<ImageModel?> watchSeriesCover(int seriesId) {
    return _db.seriesDao
        .watchSeriesCover(seriesId: seriesId)
        .map((cover) => cover != null ? ImageModel(data: cover.image) : null);
  }

  /// Watch [SeriesDetailModel] for series [seriesId]
  Stream<SeriesDetailModel> watchSeriesDetails(int seriesId) {
    return _db.seriesDao
        .watchSeriesDetail(seriesId)
        .map(SeriesDetailModel.fromDatabaseModel);
  }

  /// Watch the list of all series, optionally filterying by [libraryId]
  Stream<List<SeriesModel>> watchAllSeries({int? libraryId}) {
    return _db.seriesDao
        .allSeries(libraryId: libraryId)
        .watch()
        .distinct()
        .map(
          (list) => list.map(SeriesModel.fromDatabaseModel).toList(),
        );
  }

  /// Watch series marked as on deck
  Stream<List<SeriesModel>> watchOnDeck() {
    return _db.seriesDao.watchOnDeck().map(
      (list) => list.map(SeriesModel.fromDatabaseModel).toList(),
    );
  }

  /// Watch series marked as recently added
  Stream<List<SeriesModel>> watchRecentlyAdded() {
    return _db.seriesDao.watchRecentlyAdded().map(
      (list) => list.map(SeriesModel.fromDatabaseModel).toList(),
    );
  }

  /// Watch series marked as recently updated
  Stream<List<SeriesModel>> watchRecentlyUpdated() {
    return _db.seriesDao.watchRecentlyUpdated().map(
      (list) => list.map(SeriesModel.fromDatabaseModel).toList(),
    );
  }

  /// Refresh all series and align the local library to the remote.
  /// Note: this deletes all series not present on the server anymore.
  Future<void> refreshAllSeries() async {
    final series = await _client.getAllSeries();
    await _db.seriesDao.mergeSeries(series);
    final seriesById = {for (final s in series) s.id.value: s};
    final rows = await _db.seriesDao.allSeries().get();

    final detailsToFetch = rows
        .where(
          (r) {
            final companion = seriesById[r.id];
            if (companion == null) {
              return false;
            }

            return r.lastSynced == null ||
                (companion.lastChapterAdded.value != null &&
                    r.lastSynced!.isBefore(companion.lastChapterAdded.value!));
          },
        )
        .map((r) => r.id);

    await refreshSeriesDetails(detailsToFetch);
  }

  /// Fetch missing metadata for all series
  Future<void> fetchMissingMetadata() async {
    final series = await _db.seriesMetadataDao.getMissingSeriesIds();

    final metadata = <SeriesMetadataCompanions>[];
    for (final id in series) {
      metadata.add(await _client.getSeriesMetadata(id));
    }

    await _db.seriesMetadataDao.upsertMetadataBatch(metadata);
  }

  /// Refresh recently added series.
  Future<void> refreshRecentlyAdded() async {
    final series = await _client.getRecentlyAdded();
    await _db.seriesDao.upsertRecentlyAdded(series);
  }

  /// Refresh recently updated series.
  Future<void> refreshRecentlyUpdated() async {
    final series = await _client.getRecentlyUpdated();
    await _db.seriesDao.upsertRecentlyUpdated(series);
  }

  /// Refresh series details for a list of series
  Future<void> refreshSeriesDetails(Iterable<int> seriesIds) async {
    for (final id in seriesIds) {
      final details = await _client.getSeriesDetail(id);
      await _db.seriesDao.mergeSeriesDetails(
        details,
      );
    }
  }

  /// Fetch all missing series covers
  Future<void> fetchMissingCovers() async {
    final missingIds = await _db.seriesDao.getMissingCovers();
    for (final id in missingIds) {
      final seriesCover = await _client.getSeriesCover(id);
      await _db.seriesDao.upsertSeriesCover(seriesCover);
    }
  }

  /// Refresh all covers for series [seriesId], including volume and chapter covers.
  Future<void> refreshCovers({required int seriesId}) async {
    final seriesCover = await _client.getSeriesCover(seriesId);
    await _db.seriesDao.upsertSeriesCover(seriesCover);
    final details = await _client.getSeriesDetail(seriesId);
    final volumeIds = details.volumes.map((v) => v.volume.id.value).toList();

    for (final volumeId in volumeIds) {
      final volumeCover = await _volumeClient.getVolumeCover(volumeId);
      await _db.volumesDao.upsertVolumeCover(volumeCover);
    }

    final chapters = details.volumes.expand((v) => v.chapters).toList();
    chapters.addAll(details.chapters);
    chapters.addAll(details.storyline);
    final chapterIds = chapters.map((c) => c.id.value).toSet();

    for (final chapterId in chapterIds) {
      final chapterCover = await _chapterClient.getChapterCover(chapterId);
      await _db.chaptersDao.upsertChapterCover(chapterCover);
    }
  }
}
