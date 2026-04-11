import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
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
  );
}

class DownloadRepository {
  final AppDatabase _db;
  final BookSyncOperations _bookClient;
  final ChapterSyncOperations _chapterClient;

  DownloadRepository({
    required AppDatabase db,
    required BookSyncOperations bookClient,
    required ChapterSyncOperations chapterClient,
  }) : _db = db,
       _bookClient = bookClient,
       _chapterClient = chapterClient;

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
  Future<void> downloadChapter({required int chapterId}) async {
    // Resolve chapter metadata (page count, format).
    final chapter = await _chapterClient.getChapter(chapterId);
    final totalPages = chapter.pages.value;
    final format = chapter.format.value;

    if (totalPages == 0) {
      throw Exception('Chapter $chapterId has no pages to download');
    }

    final resumePoint = await _db.downloadDao.downloadedPageCount(
      chapterId: chapterId,
    );

    for (var page = resumePoint; page < totalPages; page++) {
      final blob = switch (format) {
        .epub => pageContentConverter.toSql(
          await _bookClient.getPageContent(chapterId: chapterId, page: page),
        ),
        .archive => await _bookClient.getImagePage(
          chapterId: chapterId,
          page: page,
        ),
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
  }

  /// Removes all locally stored pages for [chapterId].
  Future<void> deleteChapter({required int chapterId}) async {
    await _db.downloadDao.deleteChapter(chapterId: chapterId);
    log.d('deleted local pages for chapter $chapterId');
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
