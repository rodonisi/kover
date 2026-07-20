import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/models/pdf_model.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/utils/extensions/epub_page_preprocessor.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/extensions/epub_theme.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book.g.dart';

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

  final preprocessed = content.root.preprocessForRender();

  return content.copyWith(
    root: preprocessed,
    styles: content.styles,
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
Future<Map<String, Map<String, String>>> customCss(
  Ref ref, {
  required int seriesId,
}) async {
  final themeState = ref.watch(
    epubReaderSettingsProvider(
      seriesId: seriesId,
    ).select((s) => s.value?.theme),
  );
  final appTheme = await ref.watch(themeProvider.selectAsync((s) => s.theme));

  final theme = themeState?.data ?? appTheme;

  final highlightColor = theme.colorScheme.tertiaryContainer.withAlpha(0xe0);
  final onHighlightColor = theme.colorScheme.onTertiaryContainer;

  final backgroundColor = theme.colorScheme.surface;
  final onBackgroundColor = theme.colorScheme.onSurface;

  return {
    '.${HtmlConstants.resumeParagraphClass}': {
      'background-color': highlightColor.toCssRgba(),
      'color': onHighlightColor.toCssRgba(),
    },
    '.${HtmlConstants.koverWrapperClass}': {
      'background-color': backgroundColor.toCssRgba(),
      'color': onBackgroundColor.toCssRgba(),
    },
  };
}
