import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader_provider.freezed.dart';
part 'epub_reader_provider.g.dart';

@freezed
class EpubReaderModel({
  required final CommonReaderSettingsState commonSettings,
  required final EpubReaderMode mode,
  required final bool reduceAnimations,
}) with _$EpubReaderModel;

@riverpod
Future<EpubReaderModel> epubReader(
  Ref ref, {
  required int seriesId,
}) async {
  final commonSettings = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId).future,
  );
  final readerMode = await ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.mode),
  );
  final reduceAnimations = await ref.watch(
    themeProvider.selectAsync((value) => value.reduceAnimations),
  );

  return EpubReaderModel(
    commonSettings: commonSettings,
    mode: readerMode,
    reduceAnimations: reduceAnimations,
  );
}
