import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/measuring_paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/render_html.dart';
import 'package:kover/utils/html_constants.dart';
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
}

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
