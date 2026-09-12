import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/image_spreads_reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'horizontal_spreads_reader_provider.freezed.dart';
part 'horizontal_spreads_reader_provider.g.dart';

@freezed
class HorizontalSpreadsReaderModel({
  required final ImageSpreadsNavigationState navState,
  required final bool ignoreSafeAreas,
}) with _$HorizontalSpreadsReaderModel;

@riverpod
Future<HorizontalSpreadsReaderModel> horizontalSpreadsReader(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  required int? readingListId,
}) async {
  final navState = await ref.watch(
    imageSpreadsReaderNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final settings = await ref.watch(
    imageReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.ignoreSafeAreas),
  );
  return HorizontalSpreadsReaderModel(
    navState: navState,
    ignoreSafeAreas: settings,
  );
}

@freezed
class HorizontalSpreadsReaderContentModel({
  required final SpreadsState spreads,
  required final CommonReaderSettingsState commonSettings,
  required final ImageReaderSettingsState settings,
  required final bool reduceAnimations,
}) with _$HorizontalSpreadsReaderContentModel;

@riverpod
Future<HorizontalSpreadsReaderContentModel> horizontalSpreadsReaderContent(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  required int? readingListId,
}) async {
  final spreads = await ref.watch(
    spreadsProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
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

  return HorizontalSpreadsReaderContentModel(
    spreads: spreads,
    commonSettings: commonSettings,
    settings: settings,
    reduceAnimations: reduceAnimations,
  );
}
