import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';

class SyncEngine {
  final SeriesRepository seriesRepo;
  final BookRepository bookRepo;
  final LibrariesRepository librariesRepo;
  final WantToReadRepository wantToReadRepo;
  final ReaderRepository readerRepo;
  final VolumesRepository volumesRepo;
  final ChaptersRepository chaptersRepo;

  const SyncEngine({
    required this.seriesRepo,
    required this.bookRepo,
    required this.librariesRepo,
    required this.wantToReadRepo,
    required this.readerRepo,
    required this.volumesRepo,
    required this.chaptersRepo,
  });

  Future<void> syncAllSeries() async {
    await seriesRepo.refreshAllSeries();
    await seriesRepo.fetchMissingMetadata();
  }

  Future<void> syncMetadata() async {
    await seriesRepo.fetchMissingMetadata();
    await bookRepo.fetchMissingChaptersTocs();
  }

  Future<void> syncLibraries() async {
    await librariesRepo.refreshLibraries();
    await wantToReadRepo.mergeWantToRead();
  }

  Future<void> syncRecentlyUpdated() async {
    await seriesRepo.refreshRecentlyUpdated();
  }

  Future<void> syncRecentlyAdded() async {
    await seriesRepo.refreshRecentlyAdded();
  }

  Future<void> syncProgress() async {
    await readerRepo.refreshOutdatedProgress();
    await readerRepo.mergeProgress();
  }

  Future<void> syncCovers() async {
    await Future.wait([
      seriesRepo.fetchMissingCovers(),
      volumesRepo.fetchMissingCovers(),
      chaptersRepo.fetchMissingCovers(),
    ]);
  }

  Future<void> refreshCovers({required int seriesId}) async {
    await seriesRepo.refreshCovers(seriesId: seriesId);
  }
}
