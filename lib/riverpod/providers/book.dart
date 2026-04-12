import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book.g.dart';

@riverpod
Stream<List<BookChapterModel>> bookChapters(
  Ref ref, {
  required int chapterId,
}) async* {
  final repo = ref.watch(bookRepositoryProvider);
  yield* repo.watchBookChapters(chapterId).distinct();
}

@riverpod
Future<PageContent> epubPage(
  Ref ref, {
  required int chapterId,
  required int page,
}) async {
  final repo = ref.watch(bookRepositoryProvider);
  final css = await ref.watch(customCssProvider.future);
  final content = await repo.getEpubPage(chapterId: chapterId, page: page);

  return content.copyWith(styles: {...content.styles, ...css});
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
Future<Map<String, Map<String, String>>> customCss(Ref ref) async {
  final themeState = await ref.watch(themeProvider.future);
  final theme = themeState.theme;

  final highlightColor = theme.colorScheme.tertiaryContainer.withAlpha(0xe0);
  final textColor = theme.colorScheme.onTertiaryContainer;

  return {
    '.${HtmlConstants.resumeParagraphClass}': {
      'background-color': highlightColor.toCssRgba(),
      'color': textColor.toCssRgba(),
    },
  };
}
