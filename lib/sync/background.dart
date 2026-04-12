import 'package:flutter_animate/flutter_animate.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/libraries_sync_operations.dart';
import 'package:kover/sync/reader_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/sync_engine.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:kover/sync/want_to_read_sync_operations.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:workmanager/workmanager.dart';

const String _periodicTaskId = 'com.rodonisi.kover.periodic_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final db = AppDatabase();
    try {
      final settings = await db.storageDao.getSettings();
      if (settings == null) return false;

      final apiKey = settings.apiKey!;
      final chopper = getChopperClient(Uri.parse(settings.url!), apiKey);
      final client = Openapi.create(client: chopper);

      final seriesRepo = SeriesRepository(
        db: db,
        client: SeriesSyncOperations(client: client, apiKey: apiKey),
        volumeClient: VolumeSyncOperations(client: client, apiKey: apiKey),
        chapterClient: ChapterSyncOperations(client: client, apiKey: apiKey),
      );
      final bookRepo = BookRepository(
        db,
        BookSyncOperations(client: client, apiKey: apiKey),
      );
      final librariesRepo = LibrariesRepository(
        db: db,
        client: LibrariesSyncOperations(client),
      );
      final wantToReadRepo = WantToReadRepository(
        db,
        WantToReadSyncOperations(client: client),
      );
      final readerRepo = ReaderRepository(
        db: db,
        readerClient: ReaderSyncOperations(client: client),
        seriesClient: SeriesSyncOperations(client: client, apiKey: apiKey),
      );
      final volumesRepo = VolumesRepository(
        db,
        VolumeSyncOperations(client: client, apiKey: apiKey),
      );
      final chaptersRepo = ChaptersRepository(
        db,
        ChapterSyncOperations(client: client, apiKey: apiKey),
      );

      final engine = SyncEngine(
        seriesRepo: seriesRepo,
        bookRepo: bookRepo,
        librariesRepo: librariesRepo,
        wantToReadRepo: wantToReadRepo,
        readerRepo: readerRepo,
        volumesRepo: volumesRepo,
        chaptersRepo: chaptersRepo,
      );

      await engine.syncAllSeries();
      await engine.syncRecentlyUpdated();
      await engine.syncRecentlyAdded();
      await engine.syncLibraries();
      await engine.syncMetadata();
      await engine.syncProgress();

      return true;
    } catch (e) {
      log.e('failed background fetch', error: e);
    } finally {
      await db.close();
    }

    return false;
  });
}

Future<void> initializeBackgroundTask() async {
  if (SafePlatform.isIOS || SafePlatform.isAndroid) {
    await Workmanager().initialize(
      callbackDispatcher,
    );

    await Workmanager().registerPeriodicTask(
      _periodicTaskId,
      _periodicTaskId,
      frequency: 1.hours,
      flexInterval: 1.hours,
      initialDelay: 5.minutes,
      existingWorkPolicy: .keep,
      backoffPolicy: .exponential,
      constraints: Constraints(
        networkType: .connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
