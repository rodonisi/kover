import 'package:flutter/rendering.dart' show RenderFlex;
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_anchor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/render_html.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('generated pages include preserved block padding', (
    tester,
  ) async {
    const viewport = Size(180, 120);
    final text = List.filled(40, 'padding line').join(' ');
    final root = _preprocess(
      '<div style="padding: 32px 0">'
      '<p style="margin: 0">$text</p>'
      '</div>',
    );

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('generated pages include nested block padding', (tester) async {
    const viewport = Size(180, 120);
    final text = List.filled(40, 'nested padding line').join(' ');
    final root = _preprocess(
      '<div style="padding: 16px 0"><section style="padding: 16px 0">'
      '<p style="margin: 0">$text</p>'
      '</section></div>',
    );

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('generated pages handle split block margins', (tester) async {
    const viewport = Size(180, 120);
    final text = List.filled(40, 'margin line').join(' ');
    final root = _preprocess(
      '<p style="margin: 32px 0">$text</p>',
    );

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('generated pages include split-line trailing spacing', (
    tester,
  ) async {
    const viewport = Size(180, 100);
    final text = List.filled(50, 'fractional leading').join(' ');
    final root = _preprocess(
      '<p style="margin: 0; line-height: 1.43">$text</p>',
    );

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('generated chapter pages do not clip their final line', (
    tester,
  ) async {
    const viewport = Size(490.7, 910);
    final root = _preprocess(_chapterHtml());

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('production chapter pages fit the tight viewport', (
    tester,
  ) async {
    const viewport = Size(490.7, 910);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
                html: dom.DocumentFragment.html(_chapterHtml()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.subpageCount, greaterThan(1));
    final columns = tester.renderObjectList(find.byType(Column));
    expect(
      columns.whereType<RenderFlex>().any(
        (column) =>
            column.constraints.hasTightHeight &&
            column.constraints.maxHeight == viewport.height,
      ),
      isTrue,
      reason: 'The test must exercise the production tight-height Column',
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));
  });
}

String _chapterHtml() {
  final paragraphs = List.generate(40, (index) {
    return '<p style="margin: 0; text-align: justify; text-indent: 1.5em">'
        'Paragraph $index with enough justified text to wrap across several '
        'lines and exercise the final line at the chapter page boundary.'
        '</p>';
  }).join();
  return '<div style="font-family: serif; font-size: 20px; line-height: 1.2; '
      'margin: 0 5pt">'
      '<div style="margin-bottom: 2em; margin-left: 6%; margin-right: 6%; '
      'min-height: 12em; text-align: center">'
      '<h1 style="font-size: 1.29167em; line-height: 1.2; '
      'padding-top: 3.0015em; margin: 0.813857em 0 0">[ 5 ]</h1>'
      '</div>$paragraphs</div>';
}

Future<EpubPaginator> _paginate(
  WidgetTester tester,
  dom.DocumentFragment root,
  Size viewport,
) async {
  EpubMeasurements? measurements;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: EpubMeasurementsCollector(
              html: root,
              viewport: viewport,
              onMeasured: (value) => measurements = value,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(measurements, isNotNull);
  return EpubPaginator(root: root)
    ..paginate(measurements!.units, viewport.height);
}

Future<void> _expectPagesFit(
  WidgetTester tester,
  EpubPaginator paginator,
  Size viewport,
) async {
  for (var index = 0; index < paginator.subpageCount; index++) {
    final height = await _renderedPageHeight(
      tester,
      paginator.getSubpage(index),
      viewport,
    );

    expect(
      height,
      lessThanOrEqualTo(viewport.height + 0.01),
      reason: 'Subpage $index has height $height',
    );
  }
}

Future<double> _renderedPageHeight(
  WidgetTester tester,
  String html,
  Size viewport,
) async {
  final anchorKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: viewport.width,
                child: EpubMeasureAnchor(
                  key: anchorKey,
                  child: RenderHtml(
                    key: UniqueKey(),
                    html: html,
                    factoryBuilder: () =>
                        PaginatedEpubWidgetFactory(viewport: viewport),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final anchor = anchorKey.currentContext!.findRenderObject();
  return (anchor! as RenderBox).size.height;
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    root: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}
