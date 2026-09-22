import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'volume_card_provider.freezed.dart';
part 'volume_card_provider.g.dart';

@freezed
class VolumeCardModel({
  required final VolumeDetailsModel volume,
  required final ChapterModel continuePoint,
  required final bool canRead,
}) with _$VolumeCardModel;

@riverpod
Future<VolumeCardModel> volumeCard(
  Ref ref, {
  required int volumeId,
}) async {
  final volume = await ref.watch(
    volumeProvider(volumeId: volumeId).future,
  );
  final continuePoint = await ref.watch(
    volumeContinuePointProvider(volumeId: volumeId).future,
  );
  final canRead = await ref.watch(
    canReadChapterProvider(continuePoint.id).future,
  );

  return VolumeCardModel(
    volume: volume,
    continuePoint: continuePoint,
    canRead: canRead,
  );
}
