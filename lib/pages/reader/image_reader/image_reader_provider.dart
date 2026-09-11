import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_reader_provider.freezed.dart';
part 'image_reader_provider.g.dart';

@freezed
class ImageReaderModel({
  required final ReaderMode mode,
  required final ReadDirection direction,
  // required final CommonReaderSettingsState commonSettings,
  // required final ImageReaderSettingsState settings,
}) with _$ImageReaderModel;

@riverpod
Future<ImageReaderModel> imageReader(
  Ref ref, {
  required int seriesId,
}) async {
  final direction = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.readDirection),
  );
  final mode = await ref.watch(
    imageReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.readerMode),
  );

  return ImageReaderModel(
    mode: mode,
    direction: direction,
  );
}
