import 'package:kover/models/image_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'series.g.dart';

@riverpod
Stream<SeriesModel> series(Ref ref, {required int seriesId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeries(seriesId).distinct();
}

@riverpod
Future<List<SeriesModel>> searchSeries(Ref ref, String query) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.searchSeries(query);
}

@riverpod
Future<List<SeriesModel>> filterSeries(
  Ref ref,
  String query, {
  int? libraryId,
  int? collectionId,
  bool orderByName = false,
  bool orderByRecentlyAdded = false,
  bool orderByRecentlyUpdated = false,
  bool ascending = true,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.filterSeries(
    query,
    libraryId: libraryId,
    collectionId: collectionId,
    orderByName: orderByName,
    orderByRecentlyAdded: orderByRecentlyAdded,
    orderByRecentlyUpdated: orderByRecentlyUpdated,
    ascending: ascending,
  );
}

@riverpod
Stream<SeriesModel> seriesForChapter(Ref ref, {required int chapterId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeriesForChapter(chapterId).distinct();
}

@riverpod
Stream<double> seriesProgress(Ref ref, {required int seriesId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  final series = repo.watchSeries(seriesId);
  final pagesRead = repo.watchPagesRead(seriesId: seriesId);

  return Rx.combineLatest2(series, pagesRead, (s, n) => n / s.pages).distinct();
}

@riverpod
Stream<ImageModel?> seriesCover(Ref ref, {required int seriesId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeriesCover(seriesId).distinct();
}

@riverpod
Stream<List<SeriesModel>> allSeries(
  Ref ref, {
  int? libraryId,
  int? collectionId,
  bool orderByName = false,
  bool orderByRecentlyAdded = false,
  bool orderByRecentlyUpdated = false,
  bool ascending = true,
}) {
  final repo = ref.watch(seriesRepositoryProvider);

  return repo
      .watchAllSeries(
        libraryId: libraryId,
        collectionId: collectionId,
        orderByName: orderByName,
        orderByRecentlyAdded: orderByRecentlyAdded,
        orderByRecentlyUpdated: orderByRecentlyUpdated,
        ascending: ascending,
      )
      .distinct();
}

@riverpod
Stream<SeriesDetailModel> seriesDetail(
  Ref ref, {
  required int seriesId,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeriesDetails(seriesId).distinct();
}

@riverpod
Stream<SeriesMetadataModel> seriesMetadata(
  Ref ref, {
  required int seriesId,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeriesMetadata(seriesId).distinct();
}

@riverpod
Stream<List<SeriesModel>> onDeck(Ref ref) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchOnDeck().distinct();
}

@riverpod
Stream<List<SeriesModel>> recentlyUpdated(Ref ref) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchRecentlyUpdated().distinct();
}

@riverpod
Stream<List<SeriesModel>> recentlyAdded(Ref ref) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchRecentlyAdded().distinct();
}
