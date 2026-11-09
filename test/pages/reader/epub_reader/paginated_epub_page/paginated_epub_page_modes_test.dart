import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final mode in [
    EpubReaderMode.vertical,
    EpubReaderMode.spreads,
  ]) {
    testWidgets('renders ${mode.name} pages', (tester) async {
      const viewport = Size(320, 240);
      final controller = PaginatedEpubPageController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: viewport.width,
                height: viewport.height,
                child: PaginatedEpubPage(
                  controller: controller,
                  html: dom.DocumentFragment.html(_html),
                  settings: _settings(mode),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      expect(controller.subpageCount, greaterThan(0));
      expect(tester.takeException(), isNull);

      switch (mode) {
        case .vertical:
          expect(find.byType(CustomScrollView), findsWidgets);
        case .spreads:
          expect(find.byType(PageView), findsWidgets);
        case .horizontal:
          fail('horizontal is covered by the geometry tests');
      }
    });
  }
}

const _html =
    '<div>'
    '<p>First paragraph with enough text to wrap across several lines and '
    'exercise pagination in every display mode.</p>'
    '<p>Second paragraph with enough text to wrap across several lines and '
    'exercise pagination in every display mode.</p>'
    '<p>Third paragraph with enough text to wrap across several lines and '
    'exercise pagination in every display mode.</p>'
    '<p>Fourth paragraph with enough text to wrap across several lines and '
    'exercise pagination in every display mode.</p>'
    '</div>';

PaginatedEpubPageSettings _settings(EpubReaderMode mode) {
  return PaginatedEpubPageSettings(
    horizontalMarginSize: 0,
    verticalMarginSize: 0,
    fontSize: 14,
    paragraphSpacing: 0,
    lineHeight: 1.5,
    wordSpacing: 0,
    letterSpacing: 0,
    fontFamily: null,
    removeParagraphIndent: false,
    highlightResumePoint: false,
    canScroll: true,
    reduceAnimations: false,
    ignoreSafeArea: false,
    textAlignment: .left,
    mode: mode,
  );
}
