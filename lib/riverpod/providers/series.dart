import 'package:flutter/foundation.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/enums/order_by_option.dart';
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
  UnorderedSortOption orderBy = .name,
  SortDirection direction = .ascending,
  bool hideRead = false,
}) async {
  final repo = ref.watch(seriesRepositoryProvider);
  final allSeries = await ref.watch(
    allSeriesProvider(
      libraryId: libraryId,
      collectionId: collectionId,
      orderBy: orderBy,
      direction: direction,
      hideRead: hideRead,
    ).future,
  );

  if (query.isEmpty) {
    return allSeries;
  }

  return repo.filterSeries(
    query,
    libraryId: libraryId,
    collectionId: collectionId,
    orderBy: orderBy,
    direction: direction,
    hideRead: hideRead,
  );
}

@riverpod
Stream<SeriesModel> seriesForChapter(Ref ref, {required int chapterId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchSeriesForChapter(chapterId).distinct();
}

/// The ids of all chapters belonging to series [seriesId]
@riverpod
Stream<List<int>> seriesChapterIds(Ref ref, {required int seriesId}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.watchChapterIds(seriesId: seriesId).distinct(listEquals);
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
  UnorderedSortOption orderBy = .name,
  SortDirection direction = .ascending,
  bool hideRead = false,
}) {
  final repo = ref.watch(seriesRepositoryProvider);

  return repo
      .watchAllSeries(
        libraryId: libraryId,
        collectionId: collectionId,
        orderBy: orderBy,
        direction: direction,
        hideRead: hideRead,
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
Stream<List<SeriesModel>> onDeck(
  Ref ref, {
  String query = '',
  UnorderedSortOption orderBy = .lastRead,
  SortDirection direction = .descending,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo
      .watchOnDeck(query: query, orderBy: orderBy, direction: direction)
      .distinct(listEquals);
}

@riverpod
Stream<List<SeriesModel>> recentlyUpdated(
  Ref ref, {
  String query = '',
  UnorderedSortOption orderBy = .dateUpdated,
  SortDirection direction = .descending,
  bool hideRead = false,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo
      .watchRecentlyUpdated(
        query: query,
        direction: direction,
        orderBy: orderBy,
        hideRead: hideRead,
      )
      .distinct(listEquals);
}

@riverpod
Stream<List<SeriesModel>> recentlyAdded(
  Ref ref, {
  String query = '',
  UnorderedSortOption orderBy = .dateAdded,
  SortDirection direction = .descending,
  bool hideRead = false,
}) {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo
      .watchRecentlyAdded(
        query: query,
        orderBy: orderBy,
        direction: direction,
        hideRead: hideRead,
      )
      .distinct(listEquals);
}
