import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'series_app_bar_provider.freezed.dart';
part 'series_app_bar_provider.g.dart';

@freezed
sealed class SeriesAppBarContinueButtonState
    with _$SeriesAppBarContinueButtonState {
  const factory SeriesAppBarContinueButtonState({
    required bool canRead,
    required double? progress,
    required ChapterModel chapter,
  }) = _SeriesAppBarContinueButtonState;
}

@riverpod
Future<SeriesAppBarContinueButtonState> seriesAppBarContinueButton(
  Ref ref, {
  required int seriesId,
}) async {
  final continuePointFuture = ref.watch(
    continuePointProvider(seriesId: seriesId).future,
  );
  final canReadFuture = ref.watch(canReadSeriesProvider(seriesId).future);
  final progress = ref
      .watch(continuePointProgressProvider(seriesId: seriesId))
      .value;

  final continuePoint = await continuePointFuture;
  final canRead = await canReadFuture;

  return SeriesAppBarContinueButtonState(
    canRead: canRead,
    progress: progress,
    chapter: continuePoint,
  );
}
