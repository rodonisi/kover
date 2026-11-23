import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/ensure_annotations_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

const _color = Color(0xFFFF0000);

void main() {
  group('EnsureAnnotationsOperation', () {
    test('when annotation is missing, then injects a highlight', () {
      final root = _process(
        '<div><p>Hello world</p></div>',
        annotations: [
          _annotation(
            id: 1,
            serverId: 7,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'world',
          ),
        ],
      );

      final highlight = root.querySelector(
        HtmlConstants.kavitaHighlightElementTag,
      );
      expect(highlight, isNotNull);
      expect(highlight!.text, 'world');
      expect(
        highlight.attributes[HtmlConstants.koverAnnotationIdAttribute],
        '1',
      );
      expect(
        highlight.attributes[HtmlConstants.kavitaAnnotationIdAttribute],
        '7',
      );
      expect(root.querySelector('p')!.text, 'Hello world');
    });

    test('when annotation has no server id, then omits server attribute', () {
      final root = _process(
        '<div><p>Hello world</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'world',
          ),
        ],
      );

      final highlight = root.querySelector(
        HtmlConstants.kavitaHighlightElementTag,
      )!;
      expect(
        highlight.attributes[HtmlConstants.koverAnnotationIdAttribute],
        '1',
      );
      expect(
        highlight.attributes.containsKey(
          HtmlConstants.kavitaAnnotationIdAttribute,
        ),
        isFalse,
      );
    });

    test('when server highlight exists, then tags it with the local id', () {
      final root = _process(
        '<div><p>Hello <app-epub-highlight data-annotation-id="7">world</app-epub-highlight></p></div>',
        annotations: [
          _annotation(
            id: 1,
            serverId: 7,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'world',
          ),
        ],
      );

      final highlights = root.querySelectorAll(
        HtmlConstants.kavitaHighlightElementTag,
      );
      expect(highlights, hasLength(1));
      expect(
        highlights.single.attributes[HtmlConstants.koverAnnotationIdAttribute],
        '1',
      );
    });

    test('when text is split by an inline element, then preserves it', () {
      final root = _process(
        '<div><p>a <em>b</em> c</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'a b',
          ),
        ],
      );

      final highlights = root.querySelectorAll(
        HtmlConstants.kavitaHighlightElementTag,
      );
      expect(
        highlights.map((element) => element.text),
        ['a ', 'b'],
      );
      expect(
        root
            .querySelector('em')!
            .querySelector(
              HtmlConstants.kavitaHighlightElementTag,
            ),
        isNotNull,
      );
      expect(root.querySelector('p')!.text, 'a b c');
    });

    test('when whitespace differs, then still matches selected text', () {
      final root = _process(
        '<div><p>Spice and    Wolf</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'and Wolf',
          ),
        ],
      );

      final highlight = root.querySelector(
        HtmlConstants.kavitaHighlightElementTag,
      )!;
      expect(highlight.text, 'and    Wolf');
    });

    test('when selection spans blocks, then highlights both blocks', () {
      final root = _process(
        '<div><p>Hello</p><p>World</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            endXpath: '//div/div[1]/p[2]',
            selectedText: 'lo Wor',
          ),
        ],
      );

      final paragraphs = root.querySelectorAll('p');
      expect(paragraphs[0].text, 'Hello');
      expect(paragraphs[1].text, 'World');
      expect(
        paragraphs[0].innerHtml,
        'Hel<app-epub-highlight data-kover-annotation-id="1">lo</app-epub-highlight>',
      );
      expect(
        paragraphs[1].innerHtml,
        '<app-epub-highlight data-kover-annotation-id="1">Wor</app-epub-highlight>ld',
      );
    });

    test('when annotations overlap, then the first one wins', () {
      final root = _process(
        '<div><p>abcdefghij</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'cdef',
          ),
          _annotation(
            id: 2,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'efgh',
          ),
        ],
      );

      expect(
        root.querySelector('p')!.innerHtml,
        'ab<app-epub-highlight data-kover-annotation-id="1">cdef</app-epub-highlight><app-epub-highlight data-kover-annotation-id="2">gh</app-epub-highlight>ij',
      );
    });

    test('when selection overlaps an existing highlight, then skips it', () {
      final root = _process(
        '<div><p>ab<app-epub-highlight data-annotation-id="7">cd</app-epub-highlight>ef</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'cde',
          ),
        ],
      );

      final highlights = root.querySelectorAll(
        HtmlConstants.kavitaHighlightElementTag,
      );
      expect(highlights, hasLength(2));
      expect(
        highlights.map((element) => element.text),
        ['cd', 'e'],
      );
      expect(root.querySelector('p')!.text, 'abcdef');
    });

    test('when selected text is not found, then leaves the page untouched', () {
      final root = _process(
        '<div><p>abc</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[1]',
            selectedText: 'missing',
          ),
        ],
      );

      expect(
        root.querySelector(HtmlConstants.kavitaHighlightElementTag),
        isNull,
      );
    });

    test('when xpath is unknown, then leaves the page untouched', () {
      final root = _process(
        '<div><p>abc</p></div>',
        annotations: [
          _annotation(
            id: 1,
            xpath: '//div/div[1]/p[9]',
            selectedText: 'abc',
          ),
        ],
      );

      expect(
        root.querySelector(HtmlConstants.kavitaHighlightElementTag),
        isNull,
      );
    });
  });
}

dom.DocumentFragment _process(
  String html, {
  required List<PaginatedEpubAnnotation> annotations,
}) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [
      ScrollIdOperation(),
      EnsureAnnotationsOperation(annotations: annotations),
    ],
  ).process();
}

PaginatedEpubAnnotation _annotation({
  required int id,
  int? serverId,
  required String xpath,
  String? endXpath,
  required String selectedText,
}) {
  return PaginatedEpubAnnotation(
    id: id,
    serverId: serverId,
    xpath: xpath,
    endXpath: endXpath ?? xpath,
    selectedText: selectedText,
    color: _color,
  );
}
