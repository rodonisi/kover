import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/selection/epub_selection_registry.dart';
import 'package:material_ui/material_ui.dart';

const _html =
    '<div>'
    '<p>First paragraph text.</p>'
    '<p>Second <em>paragraph</em> text.</p>'
    '<p>Third paragraph text.</p>'
    '</div>';

const _twoSubpagesHtml =
    '<div>'
    '<p>First paragraph.</p>'
    '<p>Second paragraph.</p>'
    '<p>Third paragraph.</p>'
    '<p>Fourth paragraph.</p>'
    '</div>';

void main() {
  // Two subpages next to each other, like the columns of a spread or a
  // subpage that a page view keeps built off screen.
  group('EpubSubpageSelectionContainer', () {
    testWidgets('keeps a selection inside its subpage', (tester) async {
      final registry = await _pumpSideBySide(tester);

      await _select(
        tester,
        from: _position(tester, 'First paragraph.', 6),
        to: _position(tester, 'Second paragraph.', 6),
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'paragraph.\n\nSecond');
      expect(draft?.endingXPath, '//body/p[2]');
    });

    testWidgets('does not select the next subpage below the last line', (
      tester,
    ) async {
      final registry = await _pumpSideBySide(tester);
      final belowLeftSubpage =
          tester.getBottomLeft(find.byType(Row)) + const Offset(20, 40);

      await _select(
        tester,
        from: _position(tester, 'First paragraph.', 6),
        to: belowLeftSubpage,
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'paragraph.\n\nSecond paragraph.');
      expect(draft?.endingXPath, '//body/p[2]');
    });

    testWidgets('continues a selection in the next subpage', (tester) async {
      final registry = await _pumpSideBySide(tester);

      // The end is higher up than the start, but in the next subpage.
      await _select(
        tester,
        from: _position(tester, 'Second paragraph.', 7),
        to: _position(tester, 'Third paragraph.', 5),
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'paragraph.\n\nThird');
      expect(draft?.xPath, '//body/p[2]');
      expect(draft?.endingXPath, '//body/p[3]');
    });
  });

  group('EpubSelectionRegistry', () {
    testWidgets('resolves nothing without a selection', (tester) async {
      final registry = await _pump(tester, _html);

      expect(registry.resolveDraft(), isNull);
    });

    testWidgets('resolves a selection inside one paragraph', (tester) async {
      final registry = await _pump(tester, _html);

      await _select(
        tester,
        from: _position(tester, 'First paragraph text.', 6),
        to: _position(tester, 'First paragraph text.', 15),
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'paragraph');
      expect(draft?.xPath, '//body/p[1]');
      expect(draft?.endingXPath, '//body/p[1]');
      expect(draft?.context, 'First paragraph text.');
    });

    testWidgets('resolves a selection across paragraphs', (tester) async {
      final registry = await _pump(tester, _html);

      await _select(
        tester,
        from: _position(tester, 'First paragraph text.', 6),
        to: _position(tester, 'Third paragraph text.', 5),
      );

      final draft = registry.resolveDraft();
      expect(
        draft?.selectedText,
        'paragraph text.\n\nSecond paragraph text.\n\nThird',
      );
      expect(draft?.xPath, '//body/p[1]');
      expect(draft?.endingXPath, '//body/p[3]');
      expect(draft?.context, 'Third paragraph text.');
    });

    testWidgets('resolves a selection made backwards', (tester) async {
      final registry = await _pump(tester, _html);

      await _select(
        tester,
        from: _position(tester, 'Second paragraph text.', 6),
        to: _position(tester, 'First paragraph text.', 6),
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'paragraph text.\n\nSecond');
      expect(draft?.xPath, '//body/p[1]');
      expect(draft?.endingXPath, '//body/p[2]');
    });

    testWidgets('joins the parts of a split paragraph with a space', (
      tester,
    ) async {
      final registry = await _pump(
        tester,
        '<div><p>Head of it</p></div>',
        secondSubpage: (html) => html
            .replaceFirst('<p ', '<p kover-starts-mid-block="" ')
            .replaceFirst('Head of it', 'and the tail.'),
      );

      await _select(
        tester,
        from: _position(tester, 'Head of it', 0),
        to: _position(tester, 'and the tail.', 7),
      );

      final draft = registry.resolveDraft();
      expect(draft?.selectedText, 'Head of it and the');
      expect(draft?.xPath, '//body/p[1]');
      expect(draft?.endingXPath, '//body/p[1]');
    });

    testWidgets('forgets blocks that are no longer rendered', (tester) async {
      final registry = await _pump(tester, _html);
      await _select(
        tester,
        from: _position(tester, 'First paragraph text.', 0),
        to: _position(tester, 'First paragraph text.', 5),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(registry.resolveDraft(), isNull);
    });
  });
}

/// Renders [html] like a subpage. [secondSubpage] derives the markup of a
/// second subpage that is rendered below the first one.
Future<EpubSelectionRegistry> _pump(
  WidgetTester tester,
  String html, {
  String Function(String html)? secondSubpage,
}) async {
  final registry = EpubSelectionRegistry();
  final subpage = EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation(), ScrollIdOperation()],
  ).process().outerHtml;

  Widget content(String html) => HtmlWidget(
    html,
    factoryBuilder: () =>
        PaginatedEpubWidgetFactory(selectionRegistry: registry),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionArea(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              content(subpage),
              if (secondSubpage != null) content(secondSubpage(subpage)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return registry;
}

/// Renders the first two paragraphs of [_twoSubpagesHtml] as one subpage and
/// the last two as another one to its right.
Future<EpubSelectionRegistry> _pumpSideBySide(WidgetTester tester) async {
  final registry = EpubSelectionRegistry();

  Widget subpage(List<int> paragraphs) {
    final root = EpubPagePreprocessor(
      html: dom.DocumentFragment.html(_twoSubpagesHtml),
      operations: [NodeIndexingOperation(), ScrollIdOperation()],
    ).process();
    final all = root.querySelectorAll('p');
    for (var index = 0; index < all.length; index++) {
      if (!paragraphs.contains(index)) all[index].remove();
    }

    return Expanded(
      child: EpubSubpageSelectionContainer(
        child: HtmlWidget(
          root.outerHtml,
          factoryBuilder: () =>
              PaginatedEpubWidgetFactory(selectionRegistry: registry),
        ),
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionArea(
          child: Row(
            crossAxisAlignment: .start,
            children: [
              subpage([0, 1]),
              subpage([2, 3]),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return registry;
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

Future<void> _select(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}
