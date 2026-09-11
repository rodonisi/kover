import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'render_epub_content_provider.freezed.dart';
part 'render_epub_content_provider.g.dart';

@freezed
class RenderEpubContentModel({
  required final EpubReaderSettingsState epubSettings,
  required final Map<String, Map<String, String>> customCss,
}) with _$RenderEpubContentModel;

@riverpod
Future<RenderEpubContentModel> renderEpubContent(
  Ref ref, {
  required int seriesId,
}) async {
  final epubSettings = await ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId).future,
  );
  final css = await ref.watch(
    customCssProvider(seriesId: seriesId).future,
  );

  return RenderEpubContentModel(
    epubSettings: epubSettings,
    customCss: css,
  );
}
