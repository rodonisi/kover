import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/collections_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/reading_lists_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/server_settings_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:pool/pool.dart';

class SyncEngine {
  final SeriesRepository seriesRepo;
  final BookRepository bookRepo;
  final LibrariesRepository librariesRepo;
  final WantToReadRepository wantToReadRepo;
  final ReaderRepository readerRepo;
  final VolumesRepository volumesRepo;
  final ChaptersRepository chaptersRepo;
  final ServerSettingsRepository serverSettingsRepo;
  final CollectionsRepository collectionsRepo;
  final ReadingListsRepository readingListsRepo;

  final _pool = Pool(4);

  SyncEngine({
    required this.seriesRepo,
    required this.bookRepo,
    required this.librariesRepo,
    required this.wantToReadRepo,
    required this.readerRepo,
    required this.volumesRepo,
    required this.chaptersRepo,
    required this.serverSettingsRepo,
    required this.collectionsRepo,
    required this.readingListsRepo,
  });

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
}
