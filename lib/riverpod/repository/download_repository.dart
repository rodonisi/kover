import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:kover/utils/cancellation_token.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_repository.g.dart';

@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);

  return DownloadRepository(
    db: db,
    bookClient: BookSyncOperations(client: client, apiKey: apiKey!),
    chapterClient: ChapterSyncOperations(client: client, apiKey: apiKey),
    volumeClient: VolumeSyncOperations(client: client, apiKey: apiKey),
    seriesClient: SeriesSyncOperations(client: client, apiKey: apiKey),
  );
}

class DownloadRepository {
  final AppDatabase _db;
  final BookSyncOperations _bookClient;
  final ChapterSyncOperations _chapterClient;
  final VolumeSyncOperations _volumeClient;
  final SeriesSyncOperations _seriesClient;

  DownloadRepository({
    required this._db,
    required this._bookClient,
    required this._chapterClient,
    required this._volumeClient,
    required this._seriesClient,
  });

  /// Whether every page of [chapterId] is persisted locally.
  Future<bool> isChapterDownloaded({required int chapterId}) {
    return _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .getSingle();
  }

  /// Reactive stream of the full-download flag.
  Stream<bool> watchIsChapterDownloaded({required int chapterId}) {
    return _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .watchSingle();
  }

  /// Emits the number of pages currently stored for [chapterId].
  Stream<double> watchDownloadProgress({required int chapterId}) {
    return _db.downloadDao.dowloadPercent(chapterId: chapterId).watchSingle();
  }

  /// Downloads every page of [chapterId] and persists the blobs to the DB.
  ///
  /// - Progress is observable via [watchDownloadedPageCount].
  /// - Any page that is already stored in the DB is skipped so that partial
  ///   downloads can be resumed.
  Future<void> downloadChapter({
    required int chapterId,
    CancellationToken? cancellationToken,
  }) async {
    final chapter = await _db.chaptersDao.chapter(chapterId).getSingle();
    final format = chapter.format;
    final totalPages = switch (format) {
      .pdf => 1,
      _ => chapter.pages,
    };

    if (totalPages == 0) {
      throw Exception('Chapter $chapterId has no pages to download');
    }

    final resumePoint = await _db.downloadDao.downloadedPageCount(
      chapterId: chapterId,
    );

    for (var page = resumePoint; page < totalPages; page++) {
      cancellationToken?.throwIfCancelled();
      final blob = switch (format) {
        .epub => pageContentConverter.toSql(
          await _bookClient.getPageContent(chapterId: chapterId, page: page),
        ),
        .archive || .image => await _bookClient.getImagePage(
          chapterId: chapterId,
          page: page,
        ),
        .pdf => await _bookClient.getPdf(chapterId: chapterId),
        _ => throw Exception('unsupported format'),
      };

      await _db.downloadDao.insertPage(
        DownloadedPagesCompanion.insert(
          chapterId: chapterId,
          page: page,
          data: blob,
          lastSync: Value(DateTime.timestamp()),
        ),
      );
    }

    await downloadMissingCovers(chapter);
  }

  Future<void> downloadMissingCovers(Chapter chapter) async {
    try {
      final chapterCover = await _db.chaptersDao
          .chapterCover(chapterId: chapter.id)
          .getSingleOrNull();

      if (chapterCover == null) {
        final remoteCover = await _chapterClient.getChapterCover(
          chapter.id,
        );
        if (remoteCover != null) {
          await _db.chaptersDao.upsertChapterCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for chapter',
        error: e,
        stacktrace: stacktrace,
        attributes: {'chapter_id': .int(chapter.id)},
      );
    }

    try {
      final volumeCover = await _db.volumesDao
          .volumeCover(volumeId: chapter.volumeId)
          .getSingleOrNull();
      if (volumeCover == null) {
        final remoteCover = await _volumeClient.getVolumeCover(
          chapter.volumeId,
        );
        if (remoteCover != null) {
          await _db.volumesDao.upsertVolumeCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for volume',
        error: e,
        stacktrace: stacktrace,
        attributes: {'volume_id': .int(chapter.volumeId)},
      );
    }

    try {
      final seriesCover = await _db.seriesDao
          .seriesCover(seriesId: chapter.seriesId)
          .getSingleOrNull();
      if (seriesCover == null) {
        final remoteCover = await _seriesClient.getSeriesCover(
          chapter.seriesId,
        );
        if (remoteCover != null) {
          await _db.seriesDao.upsertSeriesCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for series',
        error: e,
        stacktrace: stacktrace,
        attributes: {'series_id': .int(chapter.seriesId)},
      );
    }
  }

  /// Removes all locally stored pages for [chapterId].
  Future<void> deleteChapter({required int chapterId}) async {
    await _db.downloadDao.deleteChapter(chapterId: chapterId);
    log.info(
      'deleted local pages for chapter',
      attributes: {'chapter_id': .int(chapterId)},
    );
  }

  /// Emits the download progress as a percentage for all chapters belonging to
  /// [volumeId].
  Stream<double> watchVolumeDownloadProgress({
    required int volumeId,
  }) {
    return _db.downloadDao.watchDownloadedProgressByVolume(
      volumeId: volumeId,
    );
  }

  /// Cancels and deletes all downloaded pages for the chapters in [chapterIds].
  Future<void> deleteVolume(int volumeId) async {
    await _db.downloadDao.deleteVolume(volumeId: volumeId);
  }

  /// Emits the download progress as a percentage for all chapters belonging to [seriesId].
  Stream<double> watchSeriesDownloadProgress({
    required int seriesId,
  }) {
    return _db.downloadDao.watchDownloadedProgressBySeries(seriesId: seriesId);
  }

  /// Cancels and deletes all downloaded pages for every chapter in [seriesId].
  Future<void> deleteSeries({required int seriesId}) async {
    await _db.downloadDao.deleteSeries(seriesId: seriesId);
  }
}
