import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/progress_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/reader_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_repository.g.dart';

@Riverpod(keepAlive: true)
ReaderRepository readerRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final readerClient = ReaderSyncOperations(client: restClient);
  final seriesClient = SeriesSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );
  return ReaderRepository(
    db: db,
    readerClient: readerClient,
    seriesClient: seriesClient,
  );
}

class ReaderRepository {
  final AppDatabase _db;
  final ReaderSyncOperations _readerClient;
  final SeriesSyncOperations _seriesClient;

  ReaderRepository({
    required AppDatabase db,
    required ReaderSyncOperations readerClient,
    required SeriesSyncOperations seriesClient,
  }) : _db = db,
       _readerClient = readerClient,
       _seriesClient = seriesClient;

  /// Get continue point for [seriesId]
  Future<ChapterModel> getContinuePoint({required int seriesId}) async {
    final chapter = await _db.readerDao
        .continuePoint(seriesId: seriesId)
        .getSingle();
    return ChapterModel.fromDatabaseModel(chapter);
  }

  /// Watch continue point for [seriesId]
  Stream<ChapterModel> watchContinuePoint({required int seriesId}) {
    return _db.readerDao
        .continuePoint(seriesId: seriesId)
        .watchSingle()
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Watch reading progress percent for continue points of [seriesId]
  Stream<double> watchContinuePointProgress({required int seriesId}) {
    return _db.readerDao.watchContinuePointProgress(seriesId: seriesId);
  }

  Stream<ChapterModel> watchVolumeContinuePoint({required int volumeId}) {
    return _db.readerDao
        .watchVolumeContinuePoint(volumeId: volumeId)
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Get reading progress for [chapterId]
  Future<ProgressModel?> getProgress(int chapterId) async {
    final progress = await _db.readerDao.getProgress(chapterId);

    if (progress == null) {
      return null;
    }

    return ProgressModel.fromDatabaseModel(progress);
  }

  /// Watch expected previous chapter
  Stream<ChapterModel?> watchPrevChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
  }) {
    return _db.readerDao
        .watchPrevChapter(
          seriesId: seriesId,
          volumeId: volumeId,
          chapterId: chapterId,
        )
        .map((c) => c != null ? ChapterModel.fromDatabaseModel(c) : null);
  }

  /// Watch expected next chapter
  Stream<ChapterModel?> watchNextChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
  }) {
    return _db.readerDao
        .watchNextChapter(
          seriesId: seriesId,
          volumeId: volumeId,
          chapterId: chapterId,
        )
        .map((c) => c != null ? ChapterModel.fromDatabaseModel(c) : null);
  }

  /// Save local progress reading progress, setting the entry as dirty.
  /// Also tries to push the change to the server.
  Future<void> saveProgress(ProgressModel progress) async {
    final prog = await _db.readerDao.upsertProgress(
      ReadingProgressCompanion(
        chapterId: Value(progress.chapterId),
        volumeId: Value(progress.volumeId),
        seriesId: Value(progress.seriesId),
        libraryId: Value(progress.libraryId),
        pagesRead: Value(progress.pageNum),
        bookScrollId: Value(progress.bookScrollId),
        lastModified: Value(DateTime.timestamp()),
        dirty: const Value(true),
      ),
    );

    try {
      await _readerClient.sendProgress(prog);
    } catch (e) {
      log.e('could not send progress', error: e);
    }
  }

  /// Refresh complete progress for all series that have newer reading progress
  /// than local
  Future<void> refreshOutdatedProgress() async {
    final batch = <ReadingProgressCompanion>[];
    final remoteLastRead = await _seriesClient.getLastReadForSeries();
    final localLastRead = await _db.readerDao.getLastReadDatePerSeries();

    final newer = remoteLastRead.entries.where((e) {
      final local = localLastRead[e.key];
      return local == null || e.value.isAfter(local);
    });

    for (final toUpdate in newer) {
      final chaptersLastRead = await _db.readerDao
          .getLastReadDatePerSeriesChapters(seriesId: toUpdate.key);

      final outdated = chaptersLastRead.entries.where(
        (e) => e.value == null || toUpdate.value.isAfter(e.value!),
      );

      final progress = await Future.wait(
        outdated.map((c) async => await _readerClient.getProgress(c.key)),
      );

      batch.addAll(progress);
    }

    await _db.readerDao.mergeProgressBatch(batch);
  }

  /// Synchronize all dirty progress entries by sending them to the backend,
  /// refetching the updated state and finally merging it with the local state.
  Future<void> mergeProgress() async {
    final dirty = await _db.readerDao.getDirtyProgress();
    if (dirty.isEmpty) return;

    log.d('processing ${dirty.length} progress entries');

    final remoteProgress = <ReadingProgressCompanion>[];

    await Future.wait(
      dirty.map((d) async {
        remoteProgress.add(await _readerClient.getProgress(d.chapterId));
      }),
    );

    final remaining = await _db.readerDao.mergeProgressBatch(remoteProgress);

    await Future.wait(
      remaining.map((d) async {
        await _readerClient.sendProgress(d);
      }),
    );
    await _db.readerDao.clearDirtyFlags(dirty.map((e) => e.chapterId));
  }

  /// Mark [seriesId] as read. This will set the progress for all chapters
  /// belonging to this series
  Future<void> markSeriesRead(int seriesId) async {
    await _db.readerDao.markSeriesRead(seriesId, isRead: true);
  }

  /// Mark [seriesId] as unread. This will set the progress for all chapters
  /// belonging to this series
  Future<void> markSeriesUnread(int seriesId) async {
    await _db.readerDao.markSeriesRead(seriesId, isRead: false);
  }

  /// Mark [volumeId] as read. This will set the progress for all chapters
  /// belonging to this volume
  Future<void> markVolumeRead(int volumeId) async {
    await _db.readerDao.markVolumeRead(volumeId, isRead: true);
  }

  /// Mark [volumeId] as unread. This will set the progress for all chapters
  /// belonging to this volume
  Future<void> markVolumeUnread(int volumeId) async {
    await _db.readerDao.markVolumeRead(volumeId, isRead: false);
  }

  /// Mark [chapterId] as read.
  Future<void> markChapterRead(int chapterId) async {
    await _db.readerDao.markChapterRead(chapterId, isRead: true);
  }

  /// Mark [chapterId] as unread.
  Future<void> markChapterUnread(int chapterId) async {
    await _db.readerDao.markChapterRead(chapterId, isRead: false);
  }
}
