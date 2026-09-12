import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'series_card_provider.freezed.dart';
part 'series_card_provider.g.dart';

@freezed
sealed class SeriesCardModel with _$SeriesCardModel {
  const factory SeriesCardModel({
    required SeriesModel series,
    required ChapterModel continuePoint,
    required bool canRead,
  }) = _SeriesCardModel;
}

@riverpod
Future<SeriesCardModel> seriesCard(
  Ref ref, {
  required int seriesId,
}) async {
  final series = await ref.watch(
    seriesProvider(seriesId: seriesId).future,
  );
  final continuePoint = await ref.watch(
    continuePointProvider(seriesId: seriesId).future,
  );
  final canRead = await ref.watch(
    canReadSeriesProvider(seriesId).future,
  );

  return SeriesCardModel(
    series: series,
    continuePoint: continuePoint,
    canRead: canRead,
  );
}
