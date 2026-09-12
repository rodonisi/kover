import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vertical_continuous_reader_provider.freezed.dart';
part 'vertical_continuous_reader_provider.g.dart';

@freezed
class VerticalContinuousReaderModel({
  required final ReaderNavigationState navState,
  required final ImageReaderSettingsState settings,
}) with _$VerticalContinuousReaderModel;

@riverpod
Future<VerticalContinuousReaderModel> verticalContinuousReader(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  required int? readingListId,
}) async {
  final navState = await ref.watch(
    readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final settings = await ref.watch(
    imageReaderSettingsProvider(seriesId: seriesId).future,
  );

  return VerticalContinuousReaderModel(
    navState: navState,
    settings: settings,
  );
}
