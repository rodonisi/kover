import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/pdf_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pdf_reader_provider.freezed.dart';
part 'pdf_reader_provider.g.dart';

@freezed
class PdfReaderModel({
  required final ReaderState reader,
  required final CommonReaderSettingsState commonSettings,
  required final PdfReaderSettingsState settings,
  required final bool reduceAnimations,
}) with _$PdfReaderModel;

@riverpod
Future<PdfReaderModel> pdfReader(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  int? readingListId,
}) async {
  final reader = await ref.watch(
    readerProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final settings = await ref.watch(
    pdfReaderSettingsProvider(seriesId: seriesId).future,
  );
  final commonSettings = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId).future,
  );
  final reduceAnimations = await ref.watch(
    themeProvider.selectAsync((value) => value.reduceAnimations),
  );

  return PdfReaderModel(
    reader: reader,
    commonSettings: commonSettings,
    settings: settings,
    reduceAnimations: reduceAnimations,
  );
}
