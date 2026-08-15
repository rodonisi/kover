import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'volume_app_bar_provider.freezed.dart';
part 'volume_app_bar_provider.g.dart';

@freezed
sealed class VolumeAppBarContinueButtonState
    with _$VolumeAppBarContinueButtonState {
  const factory VolumeAppBarContinueButtonState({
    required bool canRead,
    required double? progress,
    required ChapterModel chapter,
  }) = _VolumeAppBarContinueButtonState;
}

@riverpod
Future<VolumeAppBarContinueButtonState> volumeAppBarContinueButton(
  Ref ref, {
  required int volumeId,
}) async {
  final continuePointFuture = ref.watch(
    volumeContinuePointProvider(volumeId: volumeId).future,
  );
  final canReadFuture = ref.watch(
    canReadVolumeProvider(volumeId).future,
  );

  final continuePoint = await continuePointFuture;
  final canRead = await canReadFuture;

  final progress = ref
      .watch(chapterProgressProvider(chapterId: continuePoint.id))
      .value;

  return VolumeAppBarContinueButtonState(
    canRead: canRead,
    progress: progress,
    chapter: continuePoint,
  );
}
