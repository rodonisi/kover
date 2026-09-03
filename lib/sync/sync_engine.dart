import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/collections_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/reading_lists_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/server_fonts_repository.dart';
import 'package:kover/riverpod/repository/server_settings_repository.dart';
import 'package:kover/riverpod/repository/smart_filters_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/collection_sync_operations.dart';
import 'package:kover/sync/font_sync_operations.dart';
import 'package:kover/sync/libraries_sync_operations.dart';
import 'package:kover/sync/reader_sync_operations.dart';
import 'package:kover/sync/reading_list_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/server_settings_sync_operations.dart';
import 'package:kover/sync/smart_filters_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:kover/sync/want_to_read_sync_operations.dart';
import 'package:pool/pool.dart';

class SyncEngine({
  required final SeriesRepository seriesRepo,
  required final BookRepository bookRepo,
  required final LibrariesRepository librariesRepo,
  required final WantToReadRepository wantToReadRepo,
  required final ReaderRepository readerRepo,
  required final VolumesRepository volumesRepo,
  required final ChaptersRepository chaptersRepo,
  required final ServerSettingsRepository serverSettingsRepo,
  required final ServerFontsRepository serverFontsRepo,
  required final CollectionsRepository collectionsRepo,
  required final ReadingListsRepository readingListsRepo,
  required final SmartFiltersRepository smartFiltersRepo,
}) {
  final _pool = Pool(8);

  factory fromCredentials({
    required String url,
    required String apiKey,
    Map<String, String> customHeaders = const {},
  }) {
    final db = AppDatabase();
    final chopper = getChopperClient(
      Uri.parse(url),
      apiKey,
      customHeaders: customHeaders,
    );
    final client = Openapi.create(client: chopper);

    final seriesRepo = SeriesRepository(
      db: db,
      client: SeriesSyncOperations(client: client),
      volumeClient: VolumeSyncOperations(client: client),
      chapterClient: ChapterSyncOperations(client: client),
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
    );
    final volumesRepo = VolumesRepository(
      db: db,
      client: VolumeSyncOperations(client: client),
    );
    final chaptersRepo = ChaptersRepository(
      db: db,
      client: ChapterSyncOperations(client: client),
    );
    final serverSettingsRepo = ServerSettingsRepository(
      db: db,
      client: ServerSettingsSyncOperations(client: client),
    );
    final serverFontsRepo = ServerFontsRepository(
      db: db,
      client: FontSyncOperations(client: client),
    );
    final collectionsRepo = CollectionsRepository(
      db: db,
      client: CollectionSyncOperations(client: client),
    );
    final readingListsRepo = ReadingListsRepository(
      db: db,
      client: ReadingListSyncOperations(client: client),
    );
    final smartFiltersRepo = SmartFiltersRepository(
      db: db,
      client: SmartFiltersSyncOperations(client: client),
    );

    return SyncEngine(
      seriesRepo: seriesRepo,
      bookRepo: bookRepo,
      librariesRepo: librariesRepo,
      wantToReadRepo: wantToReadRepo,
      readerRepo: readerRepo,
      volumesRepo: volumesRepo,
      chaptersRepo: chaptersRepo,
      serverSettingsRepo: serverSettingsRepo,
      serverFontsRepo: serverFontsRepo,
      collectionsRepo: collectionsRepo,
      readingListsRepo: readingListsRepo,
      smartFiltersRepo: smartFiltersRepo,
    );
  }

  Future<void> runPhase(SyncPhase phase) async {
    final callback = phase.when(
      allSeries: () =>
          () async => await syncAllSeries(),
      metadata: () =>
          () async => await syncMetadata(),
      tocs: () =>
          () async => await syncTocs(),
      onDeck: () =>
          () async => await syncOnDeck(),
      recentlyAdded: () =>
          () async => await syncRecentlyAdded(),
      recentlyUpdated: () =>
          () async => await syncRecentlyUpdated(),
      libraries: () =>
          () async => await syncLibraries(),
      progress: () =>
          () async => await syncProgress(),
      covers: () =>
          () async => await syncCovers(),
      collections: () =>
          () async => await syncCollections(),
      readingLists: () =>
          () async => await syncReadingLists(),
      smartFilters: () =>
          () async => await syncSmartFilters(),
      sidenav: () =>
          () async => await syncSidenav(),
      dashboard: () =>
          () async => await syncDashboard(),
      refreshServerSettings: () =>
          () async => await refreshServerSettings(),
      refreshServerFonts: () =>
          () async => await refreshServerFonts(),
      refreshMetadata: (seriesId) =>
          () async => await refreshMetadataAndDetails(seriesId: seriesId),
      refreshCovers: (seriesId) =>
          () async => await refreshCovers(seriesId: seriesId),
      refreshToc: (chapterId) =>
          () async => await refreshToc(chapterId: chapterId),
    );

    await callback();
  }

  Future<void> syncAllSeries() async {
    await _pool.withResource(seriesRepo.refreshAllSeries);
    await _pool.withResource(seriesRepo.fetchMissingMetadata);
  }

  Future<void> syncMetadata() async {
    await _pool.withResource(seriesRepo.fetchMissingMetadata);
  }

  Future<void> syncTocs() async {
    await _pool.withResource(bookRepo.fetchMissingChaptersTocs);
  }

  Future<void> syncLibraries() async {
    await _pool.withResource(librariesRepo.refreshLibraries);
    await _pool.withResource(wantToReadRepo.mergeWantToRead);
  }

  Future<void> syncOnDeck() async {
    await _pool.withResource(seriesRepo.syncOnDeck);
  }

  Future<void> syncRecentlyUpdated() async {
    await _pool.withResource(seriesRepo.refreshRecentlyUpdated);
  }

  Future<void> syncRecentlyAdded() async {
    await _pool.withResource(seriesRepo.refreshRecentlyAdded);
  }

  Future<void> syncProgress() async {
    await _pool.withResource(readerRepo.refreshOutdatedProgress);
    await _pool.withResource(readerRepo.mergeProgress);
  }

  Future<void> syncCollections() async {
    await _pool.withResource(collectionsRepo.refreshCollections);
  }

  Future<void> syncReadingLists() async {
    await _pool.withResource(readingListsRepo.refreshReadingLists);
  }

  Future<void> syncCovers() async {
    await Future.wait([
      _pool.withResource(seriesRepo.fetchMissingCovers),
      _pool.withResource(volumesRepo.fetchMissingCovers),
      _pool.withResource(chaptersRepo.fetchMissingCovers),
      _pool.withResource(collectionsRepo.fetchMissingCovers),
      _pool.withResource(readingListsRepo.fetchMissingCovers),
    ]);
  }

  Future<void> syncSidenav() async {
    await _pool.withResource(librariesRepo.refreshSidenav);
  }

  Future<void> syncSmartFilters() async {
    await _pool.withResource(smartFiltersRepo.syncSmartFilters);
  }

  Future<void> syncDashboard() async {
    await _pool.withResource(librariesRepo.refreshDashboard);
  }

  Future<void> refreshMetadataAndDetails({required int seriesId}) async {
    await _pool.withResource(
      () => seriesRepo.refreshMetadataAndDetails(seriesId: seriesId),
    );
  }

  Future<void> refreshCovers({required int seriesId}) async {
    await _pool.withResource(
      () => seriesRepo.refreshCovers(seriesId: seriesId),
    );
  }

  Future<void> refreshToc({required int chapterId}) async {
    await _pool.withResource(
      () => bookRepo.refreshChapterToc(chapterId: chapterId),
    );
  }

  Future<void> refreshServerSettings() async {
    await _pool.withResource(serverSettingsRepo.refreshServerSettings);
  }

  Future<void> refreshServerFonts() async {
    await _pool.withResource(serverFontsRepo.refreshServerFonts);
  }
}
