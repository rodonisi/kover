import 'package:flutter/foundation.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/smart_filter_model.dart';
import 'package:kover/riverpod/repository/smart_filters_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'smart_filter.g.dart';

@riverpod
Stream<SmartFilterModel> smartFilter(Ref ref, {required int id}) {
  final repo = ref.watch(smartFiltersRepositoryProvider);
  return repo.watchSmartFilter(id).distinct();
}

@riverpod
Stream<List<SeriesModel>> smartFilterSeries(
  Ref ref, {
  required int smartFilterId,
  String query = '',
  UnorderedSortOption orderBy = .name,
  SortDirection direction = .ascending,
  bool hideRead = false,
  bool downloadedOnly = false,
}) {
  final repo = ref.watch(smartFiltersRepositoryProvider);
  return repo
      .watchSeries(
        smartFilterId,
        query: query,
        orderBy: orderBy,
        direction: direction,
        hideRead: hideRead,
        downloadedOnly: downloadedOnly,
      )
      .distinct(listEquals);
}

@riverpod
Stream<List<ReadingListModel>> smartFilterReadingLists(
  Ref ref, {
  required int smartFilterId,
  String query = '',
  UnorderedSortOption orderBy = .name,
  SortDirection direction = .ascending,
}) {
  final repo = ref.watch(smartFiltersRepositoryProvider);
  return repo
      .watchReadingLists(
        smartFilterId,
        query: query,
        orderBy: orderBy,
        direction: direction,
      )
      .distinct(listEquals);
}
