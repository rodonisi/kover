import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('PaginatedEpubWidgetFactory', () {
    test('fits explicit image dimensions to the viewport', () {
      final element = dom.Element.tag('img')
        ..attributes.addAll({'width': '40', 'height': '100'});

      final styles = PaginatedEpubWidgetFactory(
        viewport: const Size(100, 80),
      ).customStylesBuilder(element);

      expect(styles?['width'], '32.0px');
      expect(styles?['height'], '80.0px');
      expect(styles?['max-height'], '80.0px');
    });

    test('caps images without dimensions at the viewport height', () {
      final element = dom.Element.tag('img')..attributes['src'] = 'image.png';

      final styles = PaginatedEpubWidgetFactory(
        viewport: const Size(100, 80),
      ).customStylesBuilder(element);

      expect(styles?.containsKey('width'), isFalse);
      expect(styles?.containsKey('height'), isFalse);
      expect(styles?['max-height'], '80.0px');
    });

    test('does not cap images for an unbounded viewport', () {
      final element = dom.Element.tag('img')..attributes['src'] = 'image.png';

      final styles = PaginatedEpubWidgetFactory().customStylesBuilder(element);

      expect(styles?.containsKey('max-height'), isFalse);
    });

    test('removes outer margins on split page edges', () {
      final start = dom.Element.tag('p')
        ..attributes[HtmlConstants.splitStartAttribute] = '';
      final end = dom.Element.tag('p')
        ..attributes[HtmlConstants.splitEndAttribute] = '';

      final factory = PaginatedEpubWidgetFactory();

      expect(factory.customStylesBuilder(start)?['margin-top'], '0');
      expect(factory.customStylesBuilder(end)?['margin-bottom'], '0');
    });
  });

  group('text indent', () {
    testWidgets('positive text-indent shifts the first line', (tester) async {
      const viewport = Size(300, 600);
      const html =
          '<p style="margin: 0; font-size: 10px; text-indent: 2em">'
          'Hello world</p>';

      await _pumpHtml(tester, html, viewport);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(paragraph.text.toPlainText().codeUnitAt(0), 0xFFFC);

      final firstGlyph = paragraph.getOffsetForCaret(
        const TextPosition(offset: 1),
        Rect.zero,
      );
      expect(firstGlyph.dx, greaterThanOrEqualTo(18));
    });

    testWidgets('additional text-indent override suppresses the indent', (
      tester,
    ) async {
      const viewport = Size(300, 600);
      final root = EpubPagePreprocessor(
        html: dom.DocumentFragment.html(
          '<p style="margin: 0; font-size: 10px; text-indent: 2em">'
          'Hello world</p>',
        ),
        operations: [NodeIndexingOperation()],
      ).process();
      final html = root.outerHtml;

      await _pumpHtml(
        tester,
        html,
        viewport,
        additionalStyles: {
          '*': {'text-indent': '0'},
        },
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
    });

    testWidgets('remove paragraph indent suppresses the indent', (
      tester,
    ) async {
      const viewport = Size(300, 600);
      const html =
          '<p style="margin: 0; font-size: 10px; text-indent: 2em">'
          'Hello world</p>';

      await _pumpHtml(
        tester,
        html,
        viewport,
        removeParagraphIndent: true,
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
    });

    testWidgets('non-positive or centered text-indent is ignored', (
      tester,
    ) async {
      const viewport = Size(300, 600);
      const html =
          '<p style="margin: 0; font-size: 10px; text-indent: -2em">'
          'Negative</p>'
          '<p style="margin: 0; font-size: 10px; text-indent: 0">Zero</p>'
          '<p style="margin: 0; font-size: 10px; text-indent: 2em; '
          'text-align: center">Centered</p>'
          '<p ${HtmlConstants.splitParagraphAttribute} '
          'style="margin: 0; font-size: 10px; text-indent: 2em">Split</p>';

      await _pumpHtml(tester, html, viewport);

      final paragraphs = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .where((paragraph) => paragraph.text.toPlainText().isNotEmpty)
          .toList();

      expect(paragraphs, hasLength(4));
      for (final paragraph in paragraphs) {
        expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
      }
    });
  });

  group('anchors', () {
    testWidgets('reports same-page links to the callback', (tester) async {
      final targets = <EpubAnchorTarget>[];

      await _pumpHtml(
        tester,
        '<p><a href="#note">note</a></p>',
        const Size(300, 600),
        onAnchorTap: targets.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('note'));
      await tester.pumpAndSettle();

      expect(targets, hasLength(1));
      expect(targets.single.page, isNull);
      expect(targets.single.part, 'note');
    });

    testWidgets('reports backend page anchors to the callback', (tester) async {
      final targets = <EpubAnchorTarget>[];

      await _pumpHtml(
        tester,
        '<p><a href="javascript:void(0)" '
        'kavita-page="8" kavita-part="page_8">chapter</a></p>',
        const Size(300, 600),
        onAnchorTap: targets.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('chapter'));
      await tester.pumpAndSettle();

      expect(targets, hasLength(1));
      expect(targets.single.page, 8);
      expect(targets.single.part, 'page_8');
    });
  });
}

Future<void> _pumpHtml(
  WidgetTester tester,
  String html,
  Size viewport, {
  Map<String, Map<String, String>> additionalStyles = const {},
  bool removeParagraphIndent = false,
  void Function(EpubAnchorTarget)? onAnchorTap,
}) async {
  final engine = CssEngine(
    root: dom.DocumentFragment.html(html),
    additionalStyles: additionalStyles,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HtmlWidget(
          html,
          factoryBuilder: () => PaginatedEpubWidgetFactory(
            viewport: viewport,
            removeParagraphIndent: removeParagraphIndent,
            onAnchorTap: onAnchorTap,
          ),
          customStylesBuilder: (element) => engine.stylesFor(element: element),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
