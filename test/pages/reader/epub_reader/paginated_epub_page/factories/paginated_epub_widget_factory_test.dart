import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/widgets/util/link_hit_region.dart';
import 'package:material_ui/material_ui.dart';

const _annotationColor = Color(0xFFFF0000);
final _annotation = PaginatedEpubAnnotation(
  id: 1,
  serverId: 7,
  xpath: '//div/p[1]',
  endXpath: '//div/p[1]',
  selectedText: 'world',
  color: _annotationColor,
);

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

    test('removes outer margins on split page edges', () {
      final start = dom.Element.tag('p')
        ..attributes[HtmlConstants.trimStartAttribute] = '';
      final end = dom.Element.tag('p')
        ..attributes[HtmlConstants.trimEndAttribute] = '';

      final factory = PaginatedEpubWidgetFactory();

      expect(factory.customStylesBuilder(start)?['margin-top'], '0');
      expect(factory.customStylesBuilder(end)?['margin-bottom'], '0');
    });

    testWidgets(
      'ignores wrapper spacing and width while keeping inherited styles',
      (tester) async {
        const html =
            '<style>.book-content { width: 50%; max-width: 200px; '
            'margin: 2em auto; margin-left: 4em; padding: 2em 1em 2em 70px; '
            'color: #123456; text-align: center; }</style>'
            '<p>Hello world</p>';

        await _pumpHtml(tester, html, const Size(800, 600));

        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(paragraph.size.width, 800);
        expect(tester.getTopLeft(find.byType(RichText)), Offset.zero);
        expect(
          tester.getSize(find.byType(HtmlWidget)).height,
          paragraph.size.height,
        );
        expect(paragraph.textAlign, TextAlign.center);
        expect(paragraph.text.style?.color, const Color(0xFF123456));
      },
    );
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

    testWidgets('remove paragraph indent suppresses the indent', (
      tester,
    ) async {
      const viewport = Size(300, 600);
      const html =
          '<p style="text-indent: 2em">'
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
  });

  group('annotations', () {
    testWidgets('renders the configured highlight color', (tester) async {
      await _pumpHtml(
        tester,
        '<p>Hello <app-epub-highlight data-kover-annotation-id="1" '
        'style="background-color: blue">world</app-epub-highlight></p>',
        const Size(300, 600),
        annotations: [_annotation],
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final highlighted = (richText.text as TextSpan).children!
          .whereType<TextSpan>()
          .firstWhere((span) => span.text?.contains('world') == true);
      expect(highlighted.style?.background?.color, _annotationColor);
    });

    testWidgets('leaves unknown annotation ids untouched', (tester) async {
      await _pumpHtml(
        tester,
        '<p>Hello <app-epub-highlight data-kover-annotation-id="99">'
        'world</app-epub-highlight></p>',
        const Size(300, 600),
        annotations: [_annotation],
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(
        _textSpans(richText.text).map((span) => span.style?.background?.color),
        everyElement(isNull),
      );
    });

    testWidgets('reports a tap with the matching annotation', (tester) async {
      final tapped = <PaginatedEpubAnnotation>[];
      await _pumpHtml(
        tester,
        '<p>Hello <app-epub-highlight data-kover-annotation-id="1">'
        'world</app-epub-highlight></p>',
        const Size(300, 600),
        annotations: [_annotation],
        onAnnotationTap: tapped.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('world'));
      await tester.pumpAndSettle();

      expect(tapped, [_annotation]);
    });

    testWidgets('keeps nested links tappable', (tester) async {
      final tappedAnnotations = <PaginatedEpubAnnotation>[];
      final tappedAnchors = <EpubAnchorTarget>[];
      await _pumpHtml(
        tester,
        '<p>Hello <app-epub-highlight data-kover-annotation-id="1">'
        '<a href="#note">world</a></app-epub-highlight></p>',
        const Size(300, 600),
        annotations: [_annotation],
        onAnnotationTap: tappedAnnotations.add,
        onAnchorTap: tappedAnchors.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('world'));
      await tester.pumpAndSettle();

      expect(tappedAnnotations, isEmpty);
      expect(tappedAnchors.single.part, 'note');
    });

    testWidgets('keeps links tappable when they wrap an annotation', (
      tester,
    ) async {
      final tappedAnnotations = <PaginatedEpubAnnotation>[];
      final tappedAnchors = <EpubAnchorTarget>[];
      await _pumpHtml(
        tester,
        '<p><a href="#note"><app-epub-highlight data-kover-annotation-id="1">'
        'world</app-epub-highlight></a></p>',
        const Size(300, 600),
        annotations: [_annotation],
        onAnnotationTap: tappedAnnotations.add,
        onAnchorTap: tappedAnchors.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('world'));
      await tester.pumpAndSettle();

      expect(tappedAnnotations, isEmpty);
      expect(tappedAnchors.single.part, 'note');
    });

    testWidgets('marks block highlights as overlay-safe hit regions', (
      tester,
    ) async {
      await _pumpHtml(
        tester,
        '<app-epub-highlight data-kover-annotation-id="1" '
        'style="display: block"><p>world</p></app-epub-highlight>',
        const Size(300, 600),
        annotations: [_annotation],
        onAnnotationTap: (_) {},
      );

      expect(find.byType(LinkHitRegion), findsOneWidget);
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
  Iterable<PaginatedEpubAnnotation> annotations = const [],
  void Function(PaginatedEpubAnnotation)? onAnnotationTap,
}) async {
  final root = EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
  final engine = CssEngine(root: root, additionalStyles: additionalStyles);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HtmlWidget(
          root.outerHtml,
          factoryBuilder: () => PaginatedEpubWidgetFactory(
            viewport: viewport,
            removeParagraphIndent: removeParagraphIndent,
            onAnchorTap: onAnchorTap,
            annotations: annotations,
            onAnnotationTap: onAnnotationTap,
          ),
          customStylesBuilder: (element) => engine.stylesFor(element: element),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}
