import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/download_repository.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:kover/utils/cancellation_token.dart';

/// Engine class responsible for downloading and storing chapters.
///
/// Runs in the download worker context. Chapter metadata is fetched from the
/// server so downloads do not depend on synced local metadata.
class const DownloadEngine({required final DownloadRepository downloadRepo}) {
  /// Creates a [DownloadEngine] from the given server credentials.
  factory fromCredentials({
    required String url,
    required String apiKey,
    Map<String, String> customHeaders = const {},
    bool ignoreCertificateValidation = false,
  }) {
    final db = AppDatabase();
    final chopper = getChopperClient(
      Uri.parse(url),
      apiKey,
      customHeaders: customHeaders,
      ignoreCertificateValidation: ignoreCertificateValidation,
    );
    final client = Openapi.create(client: chopper);

    final fontRepo = FontRepository(
      db: db,
      client: BookSyncOperations(client: client, apiKey: apiKey),
    );

    final bookClient = BookSyncOperations(client: client, apiKey: apiKey);
    final chapterClient = ChapterSyncOperations(client: client);
    final volumeClient = VolumeSyncOperations(client: client);
    final seriesClient = SeriesSyncOperations(client: client);

    final downloadRepo = DownloadRepository(
      db: db,
      fontsRepository: fontRepo,
      bookClient: bookClient,
      chapterClient: chapterClient,
      volumeClient: volumeClient,
      seriesClient: seriesClient,
    );

    return DownloadEngine(downloadRepo: downloadRepo);
  }

  Future<void> downloadChapter({
    required int chapterId,
    required CancellationToken cancellationToken,
  }) {
    return downloadRepo.downloadChapter(
      chapterId: chapterId,
      cancellationToken: cancellationToken,
    );
  }
}
