import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/riverpod/managers/font_manager.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'paginated_epub_page_provider.freezed.dart';
part 'paginated_epub_page_provider.g.dart';

@freezed
class PaginatedEpubPageModel({
  required final dom.DocumentFragment html,
  required final PaginatedEpubPageSettings settings,
  required final String? resumeScrollId,
}) with _$PaginatedEpubPageModel;

@riverpod
Future<PaginatedEpubPageModel> paginatedEpubPage(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  required int? readingListId,
  required int page,
}) async {
  final settingsFuture = ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId).future,
  );
  final commonSettingsFuture = ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId).future,
  );
  final contentFuture = ref.watch(
    epubPageProvider(
      chapterId: chapterId,
      page: page,
    ).future,
  );
  final readerFuture = ref.watch(
    readerProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final reduceAnimationsFuture = ref.watch(
    themeProvider.selectAsync((value) => value.reduceAnimations),
  );

  final settings = await settingsFuture;
  final commonSettings = await commonSettingsFuture;
  final content = await contentFuture;
  final reader = await readerFuture;
  final reduceAnimations = await reduceAnimationsFuture;

  final fontManager = ref.read(fontManagerProvider.notifier);
  if (settings.fontFamily case final family?) {
    await fontManager.ensureServerFontLoaded(family);
  }
  await fontManager.ensureLoaded(content.fonts);

  final scrollId = page == reader.initialPage ? reader.bookScrollId : null;

  return PaginatedEpubPageModel(
    html: content.root,
    resumeScrollId: scrollId,
    settings: PaginatedEpubPageSettings(
      horizontalMarginSize: settings.horizontalMarginSize,
      verticalMarginSize: settings.verticalMarginSize,
      fontSize: settings.fontSize,
      paragraphSpacing: settings.paragraphSpacing,
      lineHeight: settings.lineHeight,
      wordSpacing: settings.wordSpacing,
      letterSpacing: settings.letterSpacing,
      fontFamily: settings.fontFamily,
      removeParagraphIndent: settings.removeParagraphIndent,
      highlightResumePoint: settings.highlightResumePoint,
      canScroll: commonSettings.navigationGersturesEnabled,
      reduceAnimations: reduceAnimations,
      textAlignment: settings.textAlignment,
      mode: settings.mode,
    ),
  );
}
