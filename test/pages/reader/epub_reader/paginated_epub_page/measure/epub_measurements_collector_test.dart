import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

const _settings = PaginatedEpubPageSettings(
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
  mode: .horizontal,
);

const _wrappingText =
    'First paragraph with enough words to wrap onto another line.';

void main() {
  group('EpubMeasurementsCollector', () {
    group('viewport', () {
      testWidgets('horizontal mode subtracts margins', (tester) async {
        final result = await _measure(
          tester,
          _preprocess('<p>Text</p>'),
          settings: _settings.copyWith(
            horizontalMarginSize: 10,
            verticalMarginSize: 5,
          ),
          outerSize: const Size(320, 200),
        );

        expect(result.viewport, const Size(300, 190));
      });

      testWidgets('spreads mode halves the width first', (tester) async {
        final result = await _measure(
          tester,
          _preprocess('<p>Text</p>'),
          settings: _settings.copyWith(
            horizontalMarginSize: 10,
            verticalMarginSize: 5,
            mode: .spreads,
          ),
          outerSize: const Size(320, 200),
        );

        expect(result.viewport, const Size(140, 190));
      });
    });

    group('empty content', () {
      testWidgets('reports no units', (tester) async {
        final result = await _measure(tester, dom.DocumentFragment());

        expect(result.measurements.units, isEmpty);
      });

      testWidgets('reports zero content height', (tester) async {
        final result = await _measure(tester, dom.DocumentFragment());

        expect(result.measurements.contentSize.height, 0);
      });
    });

    group('text blocks', () {
      testWidgets('yields a line unit', (tester) async {
        final result = await _measure(tester, _preprocess('<p>Text</p>'));

        expect(result.measurements.units.single, isA<EpubLineUnit>());
      });

      testWidgets('wraps long text into several line units', (tester) async {
        final result = await _measure(
          tester,
          _preprocess('<p>$_wrappingText</p>'),
          outerSize: const Size(160, 240),
        );

        expect(result.measurements.units.length, greaterThan(1));
      });

      testWidgets('units reference their source block', (tester) async {
        final html = _preprocess('<p>Text</p>');
        final result = await _measure(tester, html);

        expect(
          result.measurements.units.single.nodeIndex,
          _nodeIndex(html, 'p'),
        );
      });

      testWidgets('units have a positive height', (tester) async {
        final result = await _measure(
          tester,
          _preprocess('<p>$_wrappingText</p>'),
          outerSize: const Size(160, 240),
        );

        expect(
          result.measurements.units.every((unit) => unit.bottom > unit.top),
          isTrue,
        );
      });

      testWidgets('reports the content height', (tester) async {
        final result = await _measure(tester, _preprocess('<p>Text</p>'));

        expect(result.measurements.contentSize.height, greaterThan(0));
      });
    });

    group('inline markup', () {
      testWidgets('mixed font sizes stay on one line unit', (tester) async {
        final result = await _measure(
          tester,
          _preprocess(
            '<div><p><span style="font-size: 24px">ONE</span> TWO '
            '<span style="font-size: 10px">THREE</span></p></div>',
          ),
        );

        expect(
          result.measurements.units.whereType<EpubLineUnit>(),
          hasLength(1),
        );
      });

      testWidgets('anchors and breaks still yield line units', (tester) async {
        final html = _preprocess(
          '<div>'
          '<h2><a id="chapter-anchor"></a><span>Title</span><br/><br/>'
          'CHAPTER II.</h2>'
          '<p>M<sup>r.</sup> Bennet</p>'
          '</div>',
        );
        final result = await _measure(
          tester,
          html,
          outerSize: const Size(320, 600),
        );

        final measured = {
          for (final unit
              in result.measurements.units.whereType<EpubLineUnit>())
            unit.nodeIndex,
        };
        expect(
          measured,
          containsAll([
            _nodeIndex(html, 'h2'),
            _nodeIndex(html, 'p'),
          ]),
        );
      });
    });

    testWidgets('empty block yields a leaf unit', (tester) async {
      final html = _preprocess(
        '<div><p>Before.</p><div class="empty"></div><p>After.</p></div>',
      );
      final result = await _measure(tester, html);

      expect(
        result.measurements.units.whereType<EpubLeafUnit>().single.nodeIndex,
        _nodeIndex(html, '.empty'),
      );
    });

    group('padding', () {
      testWidgets('top inset includes ancestor top padding', (tester) async {
        final lines = await _paddedLines(tester);

        expect(lines.first.topInset, greaterThanOrEqualTo(32));
      });

      testWidgets('bottom inset includes ancestor bottom padding', (
        tester,
      ) async {
        final lines = await _paddedLines(tester);

        expect(lines.last.bottomInset, greaterThanOrEqualTo(32));
      });
    });
  });
}

Future<List<EpubLineUnit>> _paddedLines(WidgetTester tester) async {
  final result = await _measure(
    tester,
    _preprocess(
      '<div style="padding: 32px 0">'
      '<p style="margin: 0">Enough text to wrap across several lines in the '
      'measurement viewport and exercise block splitting.</p>'
      '</div>',
    ),
    outerSize: const Size(240, 400),
  );

  return result.measurements.units.whereType<EpubLineUnit>().toList();
}

Future<({EpubMeasurements measurements, Size viewport})> _measure(
  WidgetTester tester,
  dom.DocumentFragment html, {
  PaginatedEpubPageSettings settings = _settings,
  Size outerSize = const Size(320, 240),
}) async {
  EpubMeasurements? measurements;
  Size? viewport;

  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: outerSize.width,
          height: outerSize.height,
          child: EpubMeasurementsCollector(
            html: html,
            settings: settings,
            cssEngine: CssEngine(root: html),
            constraints: BoxConstraints.tight(outerSize),
            onMeasured: (value, measuredViewport) {
              measurements = value;
              viewport = measuredViewport;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(measurements, isNotNull, reason: 'collector did not report a value');
  return (measurements: measurements!, viewport: viewport!);
}

int _nodeIndex(dom.DocumentFragment root, String selector) {
  return int.parse(
    root.querySelector(selector)!.attributes[HtmlConstants.nodeIndexAttribute]!,
  );
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}
