import 'package:flutter/foundation.dart';
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
}) {
  final repo = ref.watch(smartFiltersRepositoryProvider);
  return repo.watchSeries(smartFilterId).distinct(listEquals);
}

@riverpod
Stream<List<ReadingListModel>> smartFilterReadingLists(
  Ref ref, {
  required int smartFilterId,
}) {
  final repo = ref.watch(smartFiltersRepositoryProvider);
  return repo.watchReadingLists(smartFilterId).distinct(listEquals);
}
