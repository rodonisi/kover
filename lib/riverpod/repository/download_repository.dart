import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:kover/utils/cancellation_token.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_repository.g.dart';

@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(restClientProvider);
  final fontsRepository = ref.watch(fontRepositoryProvider);
  final apiKey = ref.watch(apiKeyProvider);

  return DownloadRepository(
    db: db,
    fontsRepository: fontsRepository,
    bookClient: BookSyncOperations(client: client, apiKey: apiKey!),
    chapterClient: ChapterSyncOperations(client: client),
    volumeClient: VolumeSyncOperations(client: client),
    seriesClient: SeriesSyncOperations(client: client),
  );
}

class const DownloadRepository({
  required final AppDatabase _db,
  required final FontRepository _fontsRepository,
  required final BookSyncOperations _bookClient,
  required final ChapterSyncOperations _chapterClient,
  required final VolumeSyncOperations _volumeClient,
  required final SeriesSyncOperations _seriesClient,
}) {
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
  /// Chapter metadata is fetched directly from the server instead of the local
  /// DB, so a download can run before (or during) a sync without depending on
  /// chapter metadata having been synced yet. Only download data is written to
  /// the DB.
  Future<void> downloadChapter({
    required int chapterId,
    CancellationToken? cancellationToken,
  }) async {
    final chapter = await _chapterClient.getChapter(chapterId);
    final volumeId = chapter?.volumeId;
    if (chapter == null || volumeId == null) {
      throw Exception('Chapter $chapterId not found on server');
    }

    final format = chapter.format != null
        ? Format.fromDtoFormat(chapter.format!)
        : Format.unknown;

    if (format == Format.unknown) {
      throw Exception('Chapter $chapterId has an unsupported format');
    }

    if (chapter.pages == null || chapter.pages! <= 0) {
      throw Exception('Chapter $chapterId has no pages to download');
    }

    final totalPages = switch (format) {
      .pdf => 1,
      _ => chapter.pages!,
    };

    final existing = await _db.downloadDao.downloadedPageNumbers(
      chapterId: chapterId,
    );

    final missing = [
      for (var page = 0; page < totalPages; page++)
        if (!existing.contains(page)) page,
    ];

    await chunkedFetch<int, DownloadedPagesCompanion>(
      items: missing,
      chunkSize: 2,
      fetchCallback: (page) async {
        cancellationToken?.throwIfCancelled();
        final blob = switch (format) {
          .epub => await _downloadEpubPage(chapterId: chapterId, page: page),
          .archive || .image => await _bookClient.getImagePage(
            chapterId: chapterId,
            page: page,
          ),
          .pdf => await _bookClient.getPdf(chapterId: chapterId),
          _ => throw Exception('unsupported format'),
        };

        return DownloadedPagesCompanion.insert(
          chapterId: chapterId,
          page: page,
          data: blob,
          lastSync: Value(DateTime.timestamp()),
        );
      },
      upsertCallback: (batch) => _db.downloadDao.insertPagesBatch(batch),
    );

    final volume = await _volumeClient.getVolume(volumeId);
    await downloadMissingCovers(
      chapterId: chapterId,
      volumeId: volumeId,
      seriesId: volume?.seriesId,
    );
  }

  /// Downloads a single epub page, persisting its fonts to the font cache
  /// and returning the serialized page. Font bytes are stored once in the
  /// fonts table.
  Future<Uint8List> _downloadEpubPage({
    required int chapterId,
    required int page,
  }) async {
    final content = await _bookClient.getPageContent(
      chapterId: chapterId,
      page: page,
    );
    await _fontsRepository.saveFonts(content.fonts);
    return pageContentConverter.toSql(content);
  }

  Future<void> downloadMissingCovers({
    required int chapterId,
    required int volumeId,
    int? seriesId,
  }) async {
    try {
      final chapterCover = await _db.chaptersDao
          .chapterCover(chapterId: chapterId)
          .getSingleOrNull();

      if (chapterCover == null) {
        final remoteCover = await _chapterClient.getChapterCover(chapterId);
        if (remoteCover != null) {
          await _db.chaptersDao.upsertChapterCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for chapter',
        error: e,
        stacktrace: stacktrace,
        attributes: {'chapter_id': chapterId},
      );
    }

    try {
      final volumeCover = await _db.volumesDao
          .volumeCover(volumeId: volumeId)
          .getSingleOrNull();
      if (volumeCover == null) {
        final remoteCover = await _volumeClient.getVolumeCover(volumeId);
        if (remoteCover != null) {
          await _db.volumesDao.upsertVolumeCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for volume',
        error: e,
        stacktrace: stacktrace,
        attributes: {'volume_id': volumeId},
      );
    }

    if (seriesId == null) return;

    try {
      final seriesCover = await _db.seriesDao
          .seriesCover(seriesId: seriesId)
          .getSingleOrNull();
      if (seriesCover == null) {
        final remoteCover = await _seriesClient.getSeriesCover(seriesId);
        if (remoteCover != null) {
          await _db.seriesDao.upsertSeriesCover(remoteCover);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch cover for series',
        error: e,
        stacktrace: stacktrace,
        attributes: {'series_id': seriesId},
      );
    }
  }

  /// Removes all locally stored pages for [chapterId].
  Future<void> deleteChapter({required int chapterId}) async {
    await _db.downloadDao.deleteChapter(chapterId: chapterId);
    log.info(
      'deleted local pages for chapter',
      attributes: {'chapter_id': chapterId},
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
