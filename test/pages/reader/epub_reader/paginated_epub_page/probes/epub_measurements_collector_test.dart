import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/utils/extensions/epub_page_preprocessor.dart'
    as render_utils;
import 'package:kover/utils/html_constants.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('EpubMeasurementsCollector', () {
    testWidgets('harvests lines from paragraphs inside a wrapper block', (
      tester,
    ) async {
      final html = _preprocess(
        '<div>'
        '<p>First paragraph with enough words to wrap onto another line.</p>'
        '<p>Second paragraph.</p>'
        '</div>',
      );

      EpubMeasurements? measurements;
      await _pump(tester, html, (value) => measurements = value);

      final units = measurements!.units;

      expect(units.whereType<EpubLineUnit>(), isNotEmpty);
      expect(units.whereType<EpubLineUnit>().length, greaterThan(2));
      expect(units.any((unit) => unit.nodeIndex == 0), isFalse);
      expect(units.map((unit) => unit.nodeIndex).toSet(), containsAll([1, 2]));

      for (final unit in units) {
        expect(unit.bottom, greaterThan(unit.top));
      }

      final tops = units.map((unit) => unit.top).toList();
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testWidgets('harvests lines from indented markup with inline spans', (
      tester,
    ) async {
      final html = _preprocess(
        '<div class="book-content">\n'
        '  <p class="calibre1">\n'
        '    It was a bright cold day in April, and the clocks were striking\n'
        '    <span class="italic">thirteen</span>.\n'
        '  </p>\n'
        '  <p>Second&nbsp;paragraph with <a href="#">a link</a> and<br>a break.</p>\n'
        '</div>\n',
      );

      EpubMeasurements? measurements;
      await _pump(tester, html, (value) => measurements = value);

      final units = measurements!.units;

      expect(units.whereType<EpubLineUnit>(), isNotEmpty);
      expect(units.whereType<EpubLeafUnit>(), isEmpty);
    });

    testWidgets('harvests lines from paragraphs with text indent', (
      tester,
    ) async {
      final html = _preprocessForRender(
        '<div>'
        '<p style="text-indent: 4%">First paragraph with enough words to '
        'wrap onto another line when rendered in a narrow viewport.</p>'
        '<p style="text-indent: 4%">Second paragraph.</p>'
        '</div>',
      );

      EpubMeasurements? measurements;
      await _pump(tester, html, (value) => measurements = value);

      final units = measurements!.units;

      expect(units.whereType<EpubLineUnit>(), isNotEmpty);
      expect(units.whereType<EpubLeafUnit>(), isEmpty);
    });

    testWidgets('harvests lines from calibre-style markup', (tester) async {
      final html = _preprocessForRender(
        '<div>'
        '<h2 id="chapter">\n'
        '<a id="chapter-anchor"></a><span id="chapter-image"></span>\n'
        '<span class="caption">I hope Mr. Bingley will like it.</span>'
        '<br/><br/>CHAPTER II.\n'
        '</h2>'
        '<p style="text-indent: 4%">'
        '“Perhaps you mean what I overheard between him and Mr. Robinson: '
        'did not I mention it to you? Mr. Robinson’s asking him how he liked '
        'our Meryton assemblies, and whether he did not think there were a '
        'great many pretty women in the room.'
        '<span id="page-number"><a id="page-anchor"></a></span>'
        '<span style="margin-left: 0.25em">”</span>'
        '</p>'
        '<p>M<sup>r.</sup> &amp; M<sup>rs.</sup> Bennet</p>'
        '</div>',
      );

      EpubMeasurements? measurements;
      await _pump(tester, html, (value) => measurements = value);

      final units = measurements!.units;

      for (final selector in ['h2', 'p']) {
        final element = html.querySelector(selector)!;
        final nodeIndex = int.parse(
          element.attributes[HtmlConstants.nodeIndexAttribute]!,
        );
        final elementUnits = units.where((unit) => unit.nodeIndex == nodeIndex);

        expect(
          elementUnits.whereType<EpubLineUnit>(),
          isNotEmpty,
          reason: '$selector should be split into lines',
        );
        expect(
          elementUnits.whereType<EpubLeafUnit>(),
          isEmpty,
          reason: '$selector should not fall back to a leaf unit',
        );
      }
    });

    testWidgets('includes ancestor padding in line page insets', (
      tester,
    ) async {
      final html = _preprocess(
        '<div style="padding: 32px 0">'
        '<p style="margin: 0">Enough text to wrap across several lines in the '
        'measurement viewport and exercise block splitting.</p>'
        '</div>',
      );

      EpubMeasurements? measurements;
      await _pump(tester, html, (value) => measurements = value);

      final lines = measurements!.units.whereType<EpubLineUnit>();
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line.topInset, greaterThanOrEqualTo(32));
        expect(line.bottomInset, greaterThanOrEqualTo(32));
      }
    });

    testWidgets('waits for asynchronous HTML builds before measuring', (
      tester,
    ) async {
      final paragraphs = List.generate(
        400,
        (index) =>
            '<p>Paragraph $index with enough text to require an asynchronous '
            'HTML build before probes can be collected.</p>',
      ).join();
      final html = _preprocess('<div>$paragraphs</div>');

      EpubMeasurements? measurements;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpubMeasurementsCollector(
              html: html,
              viewport: const Size(500, 600),
              onMeasured: (value) => measurements = value,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(measurements, isNull);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();

      expect(measurements, isNotNull);
      expect(measurements!.units, isNotEmpty);
    });

    testWidgets('completes immediately for empty HTML', (tester) async {
      EpubMeasurements? measurements;
      await _pump(
        tester,
        dom.DocumentFragment(),
        (value) => measurements = value,
      );

      expect(measurements, isNotNull);
      expect(measurements!.units, isEmpty);
    });

    testWidgets('waits for dimensionless images before measuring', (
      tester,
    ) async {
      final html = _preprocess(
        '<img src="data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
        '/x8AAusB9Wl2nXQAAAAASUVORK5CYII=">',
      );

      EpubMeasurements? measurements;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpubMeasurementsCollector(
              html: html,
              viewport: const Size(500, 600),
              onMeasured: (value) => measurements = value,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(measurements, isNull);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump();

      expect(measurements, isNotNull);
      final leaves = measurements!.units.whereType<EpubLeafUnit>();
      expect(leaves, hasLength(1));
      expect(leaves.single.height, greaterThan(0));
    });

    testWidgets('harvests leaf probes next to text blocks', (tester) async {
      final html = _preprocess(
        '<div>'
        '<img src="data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
        '/x8AAusB9Wl2nXQAAAAASUVORK5CYII=" width="10" height="10">'
        '<p>Text after the image.</p>'
        '</div>',
      );

      EpubMeasurements? measurements;
      await _pump(
        tester,
        html,
        (value) => measurements = value,
        waitForImages: true,
      );

      final leaves = measurements!.units.whereType<EpubLeafUnit>();

      expect(leaves.any((unit) => unit.nodeIndex == 1), isTrue);
      expect(
        measurements!.units.whereType<EpubLineUnit>().isNotEmpty,
        isTrue,
      );
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  dom.DocumentFragment html,
  void Function(EpubMeasurements) onMeasured, {
  bool waitForImages = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EpubMeasurementsCollector(
          html: html,
          viewport: const Size(500, 600),
          onMeasured: onMeasured,
        ),
      ),
    ),
  );
  await tester.pump();

  if (waitForImages) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump();
  }
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    root: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}

dom.DocumentFragment _preprocessForRender(String html) {
  final root = dom.DocumentFragment.html(html);
  final preprocessed = render_utils.EpubPagePreprocessor(
    root,
  ).preprocessForRender();
  return EpubPagePreprocessor(
    root: preprocessed,
    operations: [NodeIndexingOperation()],
  ).process();
}
