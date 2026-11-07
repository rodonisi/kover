import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/measuring_paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/render_html.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

const _image =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
    '/x8AAusB9Wl2nXQAAAAASUVORK5CYII=';

void main() {
  testWidgets('measuring and rendering fit explicit image dimensions equally', (
    tester,
  ) async {
    const viewport = Size(100, 80);
    final html =
        '<img ${HtmlConstants.nodeIndexAttribute}="0" '
        'src="$_image" width="40" height="100">';

    final rendered = await _imageSize(
      tester,
      html,
      () => PaginatedEpubWidgetFactory(viewport: viewport),
    );
    final measured = await _imageSize(
      tester,
      html,
      () => MeasuringPaginatedEpubWidgetFactory(viewport: viewport),
    );

    expect(rendered, const Size(32, 80));
    expect(measured, rendered);
    expect(tester.getSize(find.byType(EpubLeafProbe)), rendered);
  });

  testWidgets('measuring preserves image loading layout without dimensions', (
    tester,
  ) async {
    const viewport = Size(100, 80);
    final html = '<img ${HtmlConstants.nodeIndexAttribute}="0" src="$_image">';

    final rendered = await _imageSize(
      tester,
      html,
      () => PaginatedEpubWidgetFactory(viewport: viewport),
    );
    final measured = await _imageSize(
      tester,
      html,
      () => MeasuringPaginatedEpubWidgetFactory(viewport: viewport),
    );

    expect(rendered.height, greaterThan(0));
    expect(measured, rendered);
    expect(tester.getSize(find.byType(EpubLeafProbe)), rendered);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RenderHtml(
            key: UniqueKey(),
            html: html,
            factoryBuilder: () =>
                PaginatedEpubWidgetFactory(viewport: viewport),
            cssEngine: CssEngine(
              root: dom.DocumentFragment.html(html),
              additionalStyles: {
                '*': {'text-indent': '0'},
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
  });

  testWidgets('remove paragraph indent suppresses the indent widget', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RenderHtml(
            key: UniqueKey(),
            html: html,
            factoryBuilder: () => PaginatedEpubWidgetFactory(
              viewport: viewport,
              removeParagraphIndent: true,
            ),
            cssEngine: CssEngine(root: dom.DocumentFragment.html(html)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
  });

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
        .where((p) => p.text.toPlainText().isNotEmpty)
        .toList();

    expect(paragraphs, hasLength(4));
    for (final paragraph in paragraphs) {
      expect(paragraph.text.toPlainText().codeUnitAt(0), isNot(0xFFFC));
    }
  });
}

Future<void> _pumpHtml(
  WidgetTester tester,
  String html,
  Size viewport,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RenderHtml(
          key: UniqueKey(),
          html: html,
          factoryBuilder: () => PaginatedEpubWidgetFactory(viewport: viewport),
          cssEngine: _engine(html),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CssEngine _engine(String html) =>
    CssEngine(root: dom.DocumentFragment.html(html));

Future<Size> _imageSize(
  WidgetTester tester,
  String html,
  WidgetFactory Function() factoryBuilder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RenderHtml(
          key: UniqueKey(),
          html: html,
          factoryBuilder: factoryBuilder,
          cssEngine: _engine(html),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();

  expect(find.byType(Image), findsOneWidget);
  return tester.getSize(find.byType(Image));
}
