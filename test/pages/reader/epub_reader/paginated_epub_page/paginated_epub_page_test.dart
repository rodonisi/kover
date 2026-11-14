import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/horizontal_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/spreads_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/vertical_epub_page_view.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'paginated_epub_page_test.mocks.dart';

const _html = '<p>Text</p>';
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

const _modeViews = {
  EpubReaderMode.horizontal: HorizontalEpubPageView,
  EpubReaderMode.vertical: VerticalEpubPageView,
  EpubReaderMode.spreads: SpreadsEpubPageView,
};

@GenerateNiceMocks([
  MockSpec<PaginatedEpubPageController>(),
  MockSpec<CssEngine>(),
])
void main() {
  late MockPaginatedEpubPageController controller;
  late MockCssEngine cssEngine;

  setUp(() {
    controller = MockPaginatedEpubPageController();
    cssEngine = MockCssEngine();
    when(controller.root).thenReturn(dom.DocumentFragment.html(_html));
    when(controller.status).thenReturn(.ready);
    when(controller.subpageCount).thenReturn(1);
    when(controller.contentViewport).thenReturn(const Size(320, 240));
    when(controller.currentSubpage).thenReturn(0);
    when(controller.getSubpage(any)).thenReturn(_html);
    when(controller.cssEngine).thenReturn(cssEngine);
  });

  group('PaginatedEpubPage', () {
    group('controller interactions', () {
      testWidgets('attaches the supplied root and resume position', (
        tester,
      ) async {
        final html = dom.DocumentFragment.html(_html);

        await _pumpPage(tester, controller, html: html, resumeScrollId: 'id');

        verify(
          controller.attachRoot(
            html,
            settings: _settings,
            initialXpath: 'id',
            additionalStyles: anyNamed('additionalStyles'),
          ),
        ).called(1);
      });

      testWidgets('updates styles on mount', (tester) async {
        await _pumpPage(tester, controller);

        verify(controller.updateStyles(any)).called(1);
      });

      testWidgets('updates settings on mount', (tester) async {
        await _pumpPage(tester, controller);

        verify(controller.updateSettings(_settings)).called(1);
      });

      testWidgets('updates the viewport from layout constraints', (
        tester,
      ) async {
        await _pumpPage(tester, controller);

        verify(controller.updateViewport(const Size(320, 240))).called(1);
      });

      testWidgets('forwards measurements with the layout key', (tester) async {
        final root = _preprocess(_html);
        when(controller.root).thenReturn(root);
        when(controller.status).thenReturn(.measuring);

        await _pumpPage(tester, controller);
        await tester.pump();

        verify(
          controller.processMeasurements(
            any,
            viewport: const Size(320, 240),
            layoutKey: _settings.layoutKey,
          ),
        ).called(1);
      });

      testWidgets('remeasures when layout settings change', (tester) async {
        final html = dom.DocumentFragment.html(_html);
        await _pumpPage(tester, controller, html: html);

        await _pumpPage(
          tester,
          controller,
          html: html,
          settings: _settings.copyWith(fontSize: 16),
        );

        verify(controller.remeasure()).called(1);
      });

      testWidgets('does not remeasure for non-layout settings', (tester) async {
        final html = dom.DocumentFragment.html(_html);
        await _pumpPage(tester, controller, html: html);

        await _pumpPage(
          tester,
          controller,
          html: html,
          settings: _settings.copyWith(highlightResumePoint: true),
        );

        verifyNever(controller.remeasure());
      });
    });

    group('rendering', () {
      testWidgets('shows a spinner while measuring', (tester) async {
        when(controller.root).thenReturn(null);
        when(controller.status).thenReturn(.measuring);

        await _pumpPage(tester, controller);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders empty when there are no subpages', (tester) async {
        when(controller.subpageCount).thenReturn(0);

        await _pumpPage(tester, controller);

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SelectionArea), findsNothing);
      });

      for (final MapEntry(key: mode, value: viewType) in _modeViews.entries) {
        testWidgets('selects ${mode.name} view', (tester) async {
          await _pumpPage(
            tester,
            controller,
            settings: _settings.copyWith(mode: mode),
          );

          expect(find.byType(viewType), findsOneWidget);
        });
      }
    });
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  PaginatedEpubPageController controller, {
  dom.DocumentFragment? html,
  String? resumeScrollId,
  PaginatedEpubPageSettings settings = _settings,
}) async {
  const viewport = Size(320, 240);
  final fragment = html ?? dom.DocumentFragment.html(_html);

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
              html: fragment,
              settings: settings,
              resumeScrollId: resumeScrollId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}
