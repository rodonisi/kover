import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'horizontal_paged_reader_provider.freezed.dart';
part 'horizontal_paged_reader_provider.g.dart';

@freezed
class HorizontalPageReaderModel({
  required final ReaderState reader,
  required final ReaderNavigationState navState,
  required final CommonReaderSettingsState commonSettings,
  required final ImageReaderSettingsState settings,
  required final bool reduceAnimations,
}) with _$HorizontalPageReaderModel;

@riverpod
Future<HorizontalPageReaderModel> horizontalPagedReader(
  Ref ref, {
  required int seriesId,
  required int chapterId,
}) async {
  final reader = await ref.watch(
    readerProvider(seriesId: seriesId, chapterId: chapterId).future,
  );
  final navState = await ref.watch(
    readerNavigationProvider(seriesId: seriesId, chapterId: chapterId).future,
  );
  final commonSettings = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId).future,
  );
  final settings = await ref.watch(
    imageReaderSettingsProvider(seriesId: seriesId).future,
  );
  final reduceAnimations = await ref.watch(
    themeProvider.selectAsync((value) => value.reduceAnimations),
  );

  return HorizontalPageReaderModel(
    reader: reader,
    navState: navState,
    commonSettings: commonSettings,
    settings: settings,
    reduceAnimations: reduceAnimations,
  );
}
