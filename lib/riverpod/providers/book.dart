import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/models/pdf_model.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/extensions/epub_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
class EpubThemeStylesModel({
  required final Map<String, String> root,
  required final Map<String, String> highlight,
}) with _$EpubThemeStylesModel;

@riverpod
Stream<List<BookChapterModel>> bookChapters(
  Ref ref, {
  required int chapterId,
}) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.watchBookChapters(chapterId).distinct();
}

@riverpod
Future<PageContent> epubPage(
  Ref ref, {
  required int chapterId,
  required int page,
}) async {
  final repo = ref.watch(bookRepositoryProvider);
  final content = await repo.getEpubPage(chapterId: chapterId, page: page);

  return content.copyWith(
    root: content.root,
  );
}

@riverpod
Future<ImageModel> imagePage(
  Ref ref, {
  required int chapterId,
  required int page,
}) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getImagePage(chapterId: chapterId, page: page);
}

@riverpod
Future<PdfModel> pdf(Ref ref, {required int chapterId}) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getPdf(chapterId: chapterId);
}

@riverpod
Future<EpubThemeStylesModel> epubThemeStyles(
  Ref ref, {
  required int seriesId,
}) async {
  final themeState = ref.watch(
    epubReaderSettingsProvider(
      seriesId: seriesId,
    ).select((s) => s.value?.theme),
  );
  final appTheme = await ref.watch(themeProvider.selectAsync((s) => s.theme));

  return epubThemeStylesFromTheme(themeState?.data ?? appTheme);
}

EpubThemeStylesModel epubThemeStylesFromTheme(ThemeData theme) {
  return EpubThemeStylesModel(
    root: {
      'background-color': theme.colorScheme.surface.toCssRgba(),
      'color': theme.colorScheme.onSurface.toCssRgba(),
    },
    highlight: {
      'background-color': theme.colorScheme.tertiaryContainer
          .withAlpha(0xe0)
          .toCssRgba(),
      'color': theme.colorScheme.onTertiaryContainer.toCssRgba(),
    },
  );
}
