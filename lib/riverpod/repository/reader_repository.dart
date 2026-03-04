import 'package:drift/drift.dart';
import 'package:fluvita/database/app_database.dart';
import 'package:fluvita/models/chapter_model.dart';
import 'package:fluvita/models/progress_model.dart';
import 'package:fluvita/riverpod/providers/client.dart';
import 'package:fluvita/riverpod/repository/database.dart';
import 'package:fluvita/sync/reader_sync_operations.dart';
import 'package:fluvita/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_repository.g.dart';

@riverpod
ReaderRepository readerRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final client = ReaderSyncOperations(client: restClient);
  return ReaderRepository(db, client);
}

class ReaderRepository {
  final AppDatabase _db;
  final ReaderSyncOperations _client;

  ReaderRepository(this._db, this._client);

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
      await _client.sendProgress(prog);
    } catch (e) {
      log.e('could not send progress', error: e);
    }
  }

  /// Refresh complete progress for continue points. Does not update dirty
  /// entries.
  Future<void> refreshContinuePointsAndProgress() async {
    final series = await _db.seriesDao.allSeries().get();
    final updates = await Future.wait(
      series.map((s) async {
        final continuePoint = await _client.getContinuePoint(s.id);
        final progress = await _client.getProgress(
          continuePoint,
        );

        return (continuePoint: continuePoint, progress: progress);
      }),
    );

    await _db.readerDao.upsertCleanProgressBatch(
      updates.map((u) => u.progress),
    );
  }

  /// Synchronize all dirty progress entries by sending them to the backend,
  /// refetching the updated state and finally merging it with the local state.
  Future<void> mergeProgress() async {
    final dirty = await _db.readerDao.getDirtyProgress();
    if (dirty.isEmpty) return;

    log.d('processing ${dirty.length} progress entries');

    final updatedProgress = <ReadingProgressCompanion>[];
    for (final d in dirty) {
      await _client.sendProgress(d);
      updatedProgress.add(await _client.getProgress(d.chapterId));
    }

    await _db.readerDao.mergeProgressBatch(updatedProgress);
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
