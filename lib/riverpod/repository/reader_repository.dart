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
    required this._db,
    required this._readerClient,
    required this._seriesClient,
  });

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

  /// Watch continue point for [volumeId]
  Stream<ChapterModel> watchVolumeContinuePoint({required int volumeId}) {
    return _db.readerDao
        .watchVolumeContinuePoint(volumeId: volumeId)
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Watch continue point for [readingListId]
  Stream<ChapterModel> watchReadingListContinuePoint({
    required int readingListId,
  }) {
    return _db.readerDao
        .watchReadingListContinuePoint(readingListId: readingListId)
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Watch reading progress percent for continue points of [readingListId]
  Stream<double> watchReadingListContinuePointProgress({
    required int readingListId,
  }) {
    return _db.readerDao.watchReadingListContinuePointProgress(
      readingListId: readingListId,
    );
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
    int? readingListId,
  }) {
    return _db.readerDao
        .watchPrevChapter(
          seriesId: seriesId,
          volumeId: volumeId,
          chapterId: chapterId,
          readingListId: readingListId,
        )
        .map((c) => c != null ? ChapterModel.fromDatabaseModel(c) : null);
  }

  /// Watch expected next chapter
  Stream<ChapterModel?> watchNextChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
    int? readingListId,
  }) {
    return _db.readerDao
        .watchNextChapter(
          seriesId: seriesId,
          volumeId: volumeId,
          chapterId: chapterId,
          readingListId: readingListId,
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
    } catch (e, stacktrace) {
      log.error(
        'could not send progress',
        error: e,
        stacktrace: stacktrace,
        attributes: {
          'chapter_id': .int(prog.chapterId),
          'volume_id': .int(prog.volumeId),
          'series_id': .int(prog.seriesId),
          'library_id': .int(prog.libraryId),
          'pages_read': .int(prog.pagesRead),
          'book_scroll_id': .string(prog.bookScrollId ?? 'null'),
          'last_modified': .string(prog.lastModified.toIso8601String()),
          'dirty': .bool(prog.dirty),
        },
      );
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

    log.info(
      'processing proress entries',
      attributes: {'count': .int(dirty.length)},
    );

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
  /// belonging to this series. Also tries to push the change through the
  /// respective API endpoint.
  Future<void> markSeriesRead(int seriesId) async {
    await _db.readerDao.markSeriesRead(seriesId, isRead: true);

    try {
      await _readerClient.markSeriesRead(seriesId);
    } catch (e, stacktrace) {
      log.error(
        'failed to mark series as read',
        error: e,
        stacktrace: stacktrace,
        attributes: {'series_id': .int(seriesId)},
      );
    }
  }

  /// Mark [seriesId] as unread. This will set the progress for all chapters
  /// belonging to this series. Also tries to push the change through the
  /// respective API endpoint.
  Future<void> markSeriesUnread(int seriesId) async {
    await _db.readerDao.markSeriesRead(seriesId, isRead: false);

    try {
      await _readerClient.markSeriesUnread(seriesId);
    } catch (e, stacktrace) {
      log.error(
        'failed to mark series as unread',
        error: e,
        stacktrace: stacktrace,
        attributes: {'series_id': .int(seriesId)},
      );
    }
  }

  /// Mark [volumeId] as read. This will set the progress for all chapters
  /// belonging to this volume. Also tries push the change through the
  /// respective API endpoint
  Future<void> markVolumeRead(int volumeId) async {
    await _db.readerDao.markVolumeRead(volumeId, isRead: true);

    try {
      final volume = await _db.volumesDao.volume(volumeId).getSingle();
      await _readerClient.markVolumeRead(
        seriesId: volume.volume.seriesId,
        volumeId: volumeId,
      );
    } catch (e, stacktrace) {
      log.error(
        'failed to mark volume as read',
        error: e,
        stacktrace: stacktrace,
        attributes: {'volume_id': .int(volumeId)},
      );
    }
  }

  /// Mark [volumeId] as unread. This will set the progress for all chapters
  /// belonging to this volume. Also tries to push the change through the
  /// respective API endpoint.
  Future<void> markVolumeUnread(int volumeId) async {
    await _db.readerDao.markVolumeRead(volumeId, isRead: false);

    try {
      final volume = await _db.volumesDao.volume(volumeId).getSingle();
      await _readerClient.markVolumeUnread(
        seriesId: volume.volume.seriesId,
        volumeId: volumeId,
      );
    } catch (e, stacktrace) {
      log.error(
        'failed to mark volume as unread',
        error: e,
        stacktrace: stacktrace,
        attributes: {'volume_id': .int(volumeId)},
      );
    }
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
