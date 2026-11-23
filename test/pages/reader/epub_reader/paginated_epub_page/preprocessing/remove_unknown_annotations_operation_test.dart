import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/remove_unknown_annotations_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

const _color = Color(0xFFFF0000);

void main() {
  group('RemoveUnknownAnnotationsOperation', () {
    test('when server id is known, then keeps the highlight', () {
      final root = _process(
        '<div><p>a<app-epub-highlight data-annotation-id="7">b</app-epub-highlight>c</p></div>',
        annotations: [_annotation(serverId: 7)],
      );

      final highlight = root.querySelector(
        HtmlConstants.kavitaHighlightElementTag,
      );
      expect(highlight, isNotNull);
      expect(highlight!.text, 'b');
    });

    test('when server id is unknown, then unwraps the highlight', () {
      final root = _process(
        '<div><p>a<app-epub-highlight data-annotation-id="7">b</app-epub-highlight>c</p></div>',
        annotations: [_annotation(serverId: 8)],
      );

      expect(
        root.querySelector(HtmlConstants.kavitaHighlightElementTag),
        isNull,
      );
      expect(root.querySelector('p')!.text, 'abc');
      expect(root.querySelector('p')!.innerHtml, 'abc');
    });

    test('when local annotation has no server id, then removes the tag', () {
      final root = _process(
        '<div><p><app-epub-highlight data-annotation-id="7">b</app-epub-highlight></p></div>',
        annotations: [_annotation()],
      );

      expect(
        root.querySelector(HtmlConstants.kavitaHighlightElementTag),
        isNull,
      );
      expect(root.querySelector('p')!.text, 'b');
    });

    test('when tag has no server id, then removes the tag', () {
      final root = _process(
        '<div><p><app-epub-highlight>b</app-epub-highlight></p></div>',
        annotations: [_annotation(serverId: 7)],
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
    operations: [RemoveUnknownAnnotationsOperation(annotations: annotations)],
  ).process();
}

PaginatedEpubAnnotation _annotation({int? serverId}) {
  return PaginatedEpubAnnotation(
    id: serverId ?? 1,
    serverId: serverId,
    xpath: '//div/p[1]',
    endXpath: '//div/p[1]',
    selectedText: 'b',
    color: _color,
  );
}
