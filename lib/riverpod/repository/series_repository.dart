import 'package:drift/drift.dart';
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
import 'package:kover/utils/chunked_fetch.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

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
    required this._db,
    required this._client,
    required this._volumeClient,
    required this._chapterClient,
  });

  /// Watch series [seriesId]
  Stream<SeriesModel> watchSeries(int seriesId) {
    return _db.seriesDao
        .watchSeries(seriesId)
        .whereNotNull()
        .map(SeriesModel.fromDatabaseModel);
  }

  /// Search series by [query].
  Future<List<SeriesModel>> searchSeries(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final result = await _db.seriesDao.searchSeries(
      query,
    );

    return result.map(SeriesModel.fromDatabaseModel).toList();
  }

  /// Filter series by [query]. Optionally filter by [libraryId]
  Future<List<SeriesModel>> filterSeries(
    String query, {
    int? libraryId,
    int? collectionId,
    bool orderByName = false,
    bool orderByRecentlyAdded = false,
    bool orderByRecentlyUpdated = false,
    bool ascending = true,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    final result = await _db.seriesDao.filterSeries(
      query,
      libraryId: libraryId,
      collectionId: collectionId,
      orderByName: orderByName,
      orderByRecentlyAdded: orderByRecentlyAdded,
      orderByRecentlyUpdated: orderByRecentlyUpdated,
      ascending: ascending,
    );

    return result.map(SeriesModel.fromDatabaseModel).toList();
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
        .seriesCover(seriesId: seriesId)
        .watchSingleOrNull()
        .asyncMap((
          cover,
        ) async {
          if (cover != null) {
            final image = ImageModel(data: cover.image);
            return image;
          }
          try {
            final remoteCover = await _client.getSeriesCover(seriesId);
            if (remoteCover != null) {
              return ImageModel(data: remoteCover.image.value);
            }
          } catch (e, stacktrace) {
            log.error(
              'failed to fetch series cover for series',
              error: e,
              stacktrace: stacktrace,
              attributes: {
                'series_id': seriesId,
              },
            );
          }

          return null;
        });
  }

  /// Watch [SeriesDetailModel] for series [seriesId]
  Stream<SeriesDetailModel> watchSeriesDetails(int seriesId) {
    return _db.seriesDao
        .watchSeriesDetail(seriesId)
        .map(SeriesDetailModel.fromDatabaseModel);
  }

  /// Watch the list of all series, optionally filterying by [libraryId]
  Stream<List<SeriesModel>> watchAllSeries({
    int? libraryId,
    int? collectionId,
    bool orderByName = false,
    bool orderByRecentlyAdded = false,
    bool orderByRecentlyUpdated = false,
    bool ascending = true,
  }) {
    return _db.seriesDao
        .allSeries(
          libraryId: libraryId,
          collectionId: collectionId,
          orderByName: orderByName,
          orderByRecentlyAdded: orderByRecentlyAdded,
          orderByRecentlyUpdated: orderByRecentlyUpdated,
          ascending: ascending,
        )
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
    final rows = await _db.seriesDao.allSeries().get();
    final series = await _client.getAllSeries();
    final seriesById = {for (final s in series) s.id.value: s};

    final detailsToFetch = rows
        .where(
          (r) {
            final companion = seriesById[r.id];
            if (companion == null) {
              return false;
            }

            final neverSynced = r.lastSynced == null;
            final hasNewChapter =
                companion.lastChapterAdded.value != null &&
                (r.lastChapterAdded == null ||
                    r.lastChapterAdded!.isBefore(
                      companion.lastChapterAdded.value!,
                    ));
            final hasNewProgress =
                companion.remoteLastRead.value != null &&
                (r.remoteLastRead == null ||
                    r.remoteLastRead!.isBefore(
                      companion.remoteLastRead.value!,
                    ));

            return neverSynced || hasNewChapter || hasNewProgress;
          },
        )
        .map((r) => r.id);

    final newSeriesIds = seriesById.keys.toSet().difference(
      rows.map((r) => r.id).toSet(),
    );

    await refreshSeriesDetails([...detailsToFetch, ...newSeriesIds]);
    await _db.seriesDao.mergeSeries(series);
  }

  /// Fetch missing metadata for all series
  Future<void> fetchMissingMetadata() async {
    final series = await _db.seriesMetadataDao.getMissingSeriesIds();

    final metadata = <SeriesMetadataCompanions>[];
    for (final id in series) {
      try {
        metadata.add(await _client.getSeriesMetadata(id));
      } catch (e) {
        log.warning(
          'failed to fetch series metadata for series',
          attributes: {
            'series_id': id,
            'error_type': e.runtimeType,
            'error_message': e,
          },
        );
      }
    }

    await _db.seriesMetadataDao.upsertMetadataBatch(metadata);
  }

  Future<void> refreshMetadataAndDetails({required int seriesId}) async {
    final metadata = await _client.getSeriesMetadata(seriesId);
    final details = await _client.getSeriesDetail(seriesId);
    await _db.seriesMetadataDao.upsertMetadataAndDetails(
      metadata: metadata,
      details: details,
    );
  }

  /// Mark series [seriesId] as removed from on deck. The resulting entry will
  /// be dirty.
  Future<void> removeFromOnDeck({required int seriesId}) async {
    await _db.seriesDao.upsertOnDeckRemovalBatch([
      OnDeckRemovalCompanion.insert(
        seriesId: Value(seriesId),
        dirty: const Value(true),
      ),
    ]);

    try {
      final success = await _client.removeFromOnDeck(seriesId: seriesId);
      if (success) {
        await _db.seriesDao.clearDirtyOnDeckRemovalForSeries({seriesId});
      }
    } catch (e) {
      log.info(
        'failed to immediately push on deck removal for series, leaving dirty.',
        attributes: {
          'series_id': seriesId,
          'error_type': e.runtimeType,
          'error_message': e,
        },
      );
    }
  }

  /// Synchronize the on deck series list with the remote.
  /// All series that are not on deck on the remote and have no dirty local
  /// progress will be removed from the local on deck list.
  /// All dirty on deck removals will be pushed to the remote unless the remote
  /// progress is newer than the entry.
  Future<void> syncOnDeck() async {
    final remoteSeries = await _client.getOnDeck();
    final localOnDeck = await _db.seriesDao.getOnDeck();
    final localOnDeckIds = localOnDeck.map((s) => s.id).toSet();
    final remoteOnDeckIds = remoteSeries.map((s) => s.id.value).toSet();

    final delta = localOnDeckIds
        .difference(remoteOnDeckIds)
        .map((id) => OnDeckRemovalCompanion.insert(seriesId: Value(id)));

    await _db.seriesDao.upsertOnDeckRemovalBatch(delta);

    final dirtyRemovals = await _db.seriesDao.getDirtyOnDeckRemovalSeriesIds();
    final outdatedRemovals = dirtyRemovals.where((entry) {
      final series = remoteSeries
          .where(
            (s) => s.id.value == entry.seriesId,
          )
          .firstOrNull;

      final remoteLastRead = series?.remoteLastRead.value;

      return remoteLastRead != null && remoteLastRead.isAfter(entry.created);
    });

    if (outdatedRemovals.isNotEmpty) {
      await _db.seriesDao.clearOnDeckRemovalForSeriesBatch(
        outdatedRemovals.map((e) => e.seriesId).toSet(),
        cleanOnly: false,
      );
      log.info(
        'cleared outdated on deck removals',
        attributes: {
          'count': outdatedRemovals.length,
          'series_ids': outdatedRemovals.map((e) => e.seriesId).toList(),
        },
      );
    }

    final remainingDirtyRemovals = dirtyRemovals
        .where((entry) => !outdatedRemovals.contains(entry))
        .map((e) => e.seriesId)
        .toSet();

    await chunkedFetch(
      items: remainingDirtyRemovals,
      fetchCallback: (seriesId) async {
        try {
          final success = await _client.removeFromOnDeck(seriesId: seriesId);
          if (success) {
            return seriesId;
          }
          return null;
        } catch (e) {
          log.warning(
            'failed to remove series from on deck',
            attributes: {
              'series_id': seriesId,
              'error_type': e.runtimeType,
              'error_message': e,
            },
          );
          return null;
        }
      },
      upsertCallback: (removedIds) async {
        final removed = removedIds.whereType<int>().toSet();

        if (removed.isEmpty) return;

        await _db.seriesDao.clearDirtyOnDeckRemovalForSeries(removed);
        log.info(
          'pushed on deck removals',
          attributes: {
            'count': removed.length,
            'series_ids': removed,
          },
        );
      },
    );
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
      try {
        final details = await _client.getSeriesDetail(id);
        await _db.seriesDao.mergeSeriesDetails(
          details,
        );
      } catch (e) {
        log.warning(
          'failed to fetch series details for series',
          attributes: {
            'series_id': id,
            'error_type': e.runtimeType,
            'error_message': e,
          },
        );
      }
    }
  }

  /// Fetch all missing series covers
  Future<void> fetchMissingCovers() async {
    final missingIds = await _db.seriesDao.getMissingCovers();
    await chunkedFetch(
      items: missingIds,
      fetchCallback: (id) async => _client.getSeriesCover(id),
      upsertCallback: (covers) async => _db.seriesDao.upsertSeriesCoversBatch(
        covers.whereType<SeriesCoversCompanion>(),
      ),
    );
  }

  /// Refresh all covers for series [seriesId], including volume and chapter covers.
  Future<void> refreshCovers({required int seriesId}) async {
    final seriesCover = await _client.getSeriesCover(seriesId);
    if (seriesCover != null) {
      await _db.seriesDao.upsertSeriesCover(seriesCover);
    }
    final details = await _client.getSeriesDetail(seriesId);
    final volumeIds = details.volumes.map((v) => v.volume.id.value).toList();
    await chunkedFetch(
      items: volumeIds,
      fetchCallback: (id) => _volumeClient.getVolumeCover(id),
      upsertCallback: (covers) async => _db.volumesDao.upsertVolumeCoversBatch(
        covers.whereType<VolumeCoversCompanion>(),
      ),
    );
    final chapters = details.volumes.expand((v) => v.chapters).toList();
    chapters.addAll(details.chapters);
    chapters.addAll(details.storyline);
    final chapterIds = chapters.map((c) => c.id.value).toSet();
    await chunkedFetch(
      items: chapterIds,
      fetchCallback: (id) => _chapterClient.getChapterCover(id),
      upsertCallback: (covers) async =>
          _db.chaptersDao.upsertChapterCoversBatch(
            covers.whereType<ChapterCoversCompanion>(),
          ),
    );
  }
}
