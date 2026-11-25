import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/horizontal_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/spreads_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/vertical_epub_page_view.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'paginated_epub_page_test.mocks.dart';

const _html = '<p>Text</p>';
const _highlightHtml =
    '<p>Hello <app-epub-highlight data-kover-annotation-id="1">'
    'world</app-epub-highlight></p>';
const _paragraphsHtml =
    '<div><p>First paragraph.</p><p>Second paragraph.</p></div>';
const _twoSubpagesHtml =
    '<div><p>First paragraph.</p><p>Second paragraph.</p>'
    '<p>Third paragraph.</p><p>Fourth paragraph.</p></div>';
final _annotation = PaginatedEpubAnnotation(
  id: 1,
  xpath: '//div/p[1]',
  endXpath: '//div/p[1]',
  selectedText: 'world',
  color: const Color(0xFFFF0000),
);
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

      testWidgets('forwards annotations to the measurement collector', (
        tester,
      ) async {
        when(controller.root).thenReturn(_preprocess(_highlightHtml));
        when(controller.status).thenReturn(.measuring);

        await _pumpPage(
          tester,
          controller,
          html: dom.DocumentFragment.html(_highlightHtml),
          annotations: [_annotation],
        );

        final collector = tester.widget<EpubMeasurementsCollector>(
          find.byType(EpubMeasurementsCollector, skipOffstage: false),
        );
        expect(collector.annotations, [_annotation]);
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

      for (final mode in EpubReaderMode.values) {
        testWidgets('opens the injected sheet in ${mode.name} mode', (
          tester,
        ) async {
          when(controller.getSubpage(any)).thenReturn(_highlightHtml);
          when(controller.annotations).thenReturn([_annotation]);
          final opened = <int>[];

          await _pumpPage(
            tester,
            controller,
            settings: _settings.copyWith(mode: mode),
            annotations: [_annotation],
            annotationSheetBuilder: (context, annotationId) {
              opened.add(annotationId);
              return const Text('annotation sheet');
            },
          );

          await tester.tapOnText(find.textRange.ofSubstring('world'));
          await tester.pumpAndSettle();

          expect(opened, [1]);
          expect(find.text('annotation sheet'), findsOneWidget);
        });
      }

      for (final mode in EpubReaderMode.values) {
        testWidgets('annotates a selection in ${mode.name} mode', (
          tester,
        ) async {
          when(controller.getSubpage(0)).thenReturn(_subpage(_paragraphsHtml));
          when(controller.canHighlight(any)).thenReturn(true);
          final drafts = <AnnotationDraft>[];

          await _pumpPage(
            tester,
            controller,
            settings: _settings.copyWith(mode: mode),
            draftSheetBuilder: (context, draft) {
              drafts.add(draft);
              return const Text('draft sheet');
            },
          );
          await _selectAndOpenMenu(tester);
          await tester.tap(find.text('Annotate'));
          await tester.pumpAndSettle();

          expect(drafts, const [
            AnnotationDraft(
              xPath: '//body/p[1]',
              endingXPath: '//body/p[2]',
              selectedText: 'paragraph.\n\nSecond',
              context: 'Second paragraph.',
            ),
          ]);
          expect(find.text('draft sheet'), findsOneWidget);
        });
      }

      group('with two subpages', () {
        final drafts = <AnnotationDraft>[];

        setUp(() {
          drafts.clear();
          when(controller.subpageCount).thenReturn(2);
          when(
            controller.getSubpage(0),
          ).thenReturn(_subpage(_twoSubpagesHtml, paragraphs: [0, 1]));
          when(
            controller.getSubpage(1),
          ).thenReturn(_subpage(_twoSubpagesHtml, paragraphs: [2, 3]));
          when(controller.canHighlight(any)).thenReturn(true);
        });

        Future<void> pump(WidgetTester tester, EpubReaderMode mode) {
          return _pumpPage(
            tester,
            controller,
            settings: _settings.copyWith(mode: mode),
            draftSheetBuilder: (context, draft) {
              drafts.add(draft);
              return const Text('draft sheet');
            },
          );
        }

        const firstSubpageDraft = AnnotationDraft(
          xPath: '//body/p[1]',
          endingXPath: '//body/p[2]',
          selectedText: 'paragraph.\n\nSecond',
          context: 'Second paragraph.',
        );

        // The page view keeps the next subpage built next to the visible
        // one, at the same rows.
        testWidgets('ignores the subpage kept off screen in horizontal mode', (
          tester,
        ) async {
          await pump(tester, .horizontal);
          await _selectAndOpenMenu(tester);
          await tester.tap(find.text('Annotate'));
          await tester.pumpAndSettle();

          expect(drafts, [firstSubpageDraft]);
        });

        testWidgets('keeps a selection inside one column in spreads mode', (
          tester,
        ) async {
          await pump(tester, .spreads);
          await _selectAndOpenMenu(tester);
          await tester.tap(find.text('Annotate'));
          await tester.pumpAndSettle();

          expect(drafts, [firstSubpageDraft]);
        });

        testWidgets('selects across columns in reading order in spreads mode', (
          tester,
        ) async {
          await pump(tester, .spreads);
          await _selectAndOpenMenu(
            tester,
            from: ('Second paragraph.', 7),
            to: ('Third paragraph.', 5),
          );
          await tester.tap(find.text('Annotate'));
          await tester.pumpAndSettle();

          expect(drafts, const [
            AnnotationDraft(
              xPath: '//body/p[2]',
              endingXPath: '//body/p[3]',
              selectedText: 'paragraph.\n\nThird',
              context: 'Third paragraph.',
            ),
          ]);
        });

        testWidgets('selects across subpages in vertical mode', (tester) async {
          await pump(tester, .vertical);
          await _selectAndOpenMenu(
            tester,
            from: ('Second paragraph.', 7),
            to: ('Third paragraph.', 5),
          );
          await tester.tap(find.text('Annotate'));
          await tester.pumpAndSettle();

          expect(drafts, const [
            AnnotationDraft(
              xPath: '//body/p[2]',
              endingXPath: '//body/p[3]',
              selectedText: 'paragraph.\n\nThird',
              context: 'Third paragraph.',
            ),
          ]);
        });
      });

      testWidgets('clears the selection when the draft sheet opens', (
        tester,
      ) async {
        when(controller.getSubpage(0)).thenReturn(_subpage(_paragraphsHtml));
        when(controller.canHighlight(any)).thenReturn(true);
        final selected = <bool>[];

        await _pumpPage(
          tester,
          controller,
          onSelectionChanged: selected.add,
          draftSheetBuilder: (context, draft) => const Text('draft sheet'),
        );
        await _selectAndOpenMenu(tester);
        await tester.tap(find.text('Annotate'));
        await tester.pumpAndSettle();

        expect(selected.last, isFalse);
      });

      testWidgets('rejects a selection that cannot be highlighted', (
        tester,
      ) async {
        when(controller.getSubpage(0)).thenReturn(_subpage(_paragraphsHtml));
        when(controller.canHighlight(any)).thenReturn(false);

        await _pumpPage(
          tester,
          controller,
          draftSheetBuilder: (context, draft) => const Text('draft sheet'),
        );
        await _selectAndOpenMenu(tester);
        await tester.tap(find.text('Annotate'));
        await tester.pumpAndSettle();

        expect(
          find.text('This selection cannot be annotated.'),
          findsOneWidget,
        );
        expect(find.text('draft sheet'), findsNothing);
      });

      testWidgets('does not offer to annotate without a draft sheet', (
        tester,
      ) async {
        when(controller.getSubpage(0)).thenReturn(_subpage(_paragraphsHtml));

        await _pumpPage(tester, controller);
        await _selectAndOpenMenu(tester);

        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Annotate'), findsNothing);
      });

      testWidgets('refreshes highlight colors when annotations change', (
        tester,
      ) async {
        when(controller.getSubpage(any)).thenReturn(_highlightHtml);
        when(controller.annotations).thenReturn([_annotation]);
        await _pumpPage(tester, controller, annotations: [_annotation]);

        Color? highlightColor() {
          final richText = tester.widget<RichText>(find.byType(RichText));
          final highlighted = (richText.text as TextSpan).children!
              .whereType<TextSpan>()
              .firstWhere((span) => span.text?.contains('world') == true);
          return highlighted.style?.background?.color;
        }

        expect(highlightColor(), _annotation.color);

        final updated = _annotation.copyWith(color: const Color(0xFF0000FF));
        when(controller.annotations).thenReturn([updated]);
        await _pumpPage(tester, controller, annotations: [updated]);

        expect(highlightColor(), updated.color);
      });
    });
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  PaginatedEpubPageController controller, {
  dom.DocumentFragment? html,
  String? resumeScrollId,
  PaginatedEpubPageSettings settings = _settings,
  Iterable<PaginatedEpubAnnotation> annotations = const [],
  EpubAnnotationSheetBuilder? annotationSheetBuilder,
  EpubAnnotationDraftSheetBuilder? draftSheetBuilder,
  void Function(bool selected)? onSelectionChanged,
}) async {
  const viewport = Size(320, 240);
  final fragment = html ?? dom.DocumentFragment.html(_html);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
              annotations: annotations.toList(growable: false),
              resumeScrollId: resumeScrollId,
              annotationSheetBuilder: annotationSheetBuilder,
              draftSheetBuilder: draftSheetBuilder,
              onSelectionChanged: onSelectionChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

/// Selects from the character at [from] to the one at [to] with the mouse,
/// then opens the selection menu with a right click. Both are a paragraph's
/// text and a character offset in it.
Future<void> _selectAndOpenMenu(
  WidgetTester tester, {
  (String, int) from = ('First paragraph.', 6),
  (String, int) to = ('Second paragraph.', 6),
}) async {
  final gesture = await tester.startGesture(
    _position(tester, from.$1, from.$2),
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(_position(tester, to.$1, to.$2));
  await tester.pump();
  await gesture.up();
  await tester.pump();

  await tester.tapAt(
    _position(tester, to.$1, to.$2 - 2),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

/// The global position of the character at [offset] in the paragraph that
/// renders [text].
Offset _position(WidgetTester tester, String text, int offset) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    ),
  );
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first;

  return paragraph.localToGlobal(
    Offset(box.left, (box.top + box.bottom) / 2),
  );
}

/// The markup of a subpage, prepared like the controller does.
///
/// With [paragraphs], only the paragraphs at these positions are kept.
String _subpage(String html, {List<int>? paragraphs}) {
  final root = EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation(), ScrollIdOperation()],
  ).process();

  if (paragraphs != null) {
    final all = root.querySelectorAll('p');
    for (var index = 0; index < all.length; index++) {
      if (!paragraphs.contains(index)) all[index].remove();
    }
  }

  return root.outerHtml;
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}
