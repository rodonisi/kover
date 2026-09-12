import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_gestures_provider.freezed.dart';
part 'overlay_gestures_provider.g.dart';

@freezed
class OverlayGesturesModel({
  required final bool navigationGestures,
  required final ReadDirection readDirection,
}) with _$OverlayGesturesModel;

@riverpod
Future<OverlayGesturesModel> overlayGestures(
  Ref ref, {
  required int seriesId,
}) async {
  final navigationGestures = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.navigationGersturesEnabled),
  );
  final readDirection = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.readDirection),
  );

  return OverlayGesturesModel(
    navigationGestures: navigationGestures,
    readDirection: readDirection,
  );
}
