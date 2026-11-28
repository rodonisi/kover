import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('ScrollIdOperation', () {
    test('writes a body-relative xpath for the content root', () {
      final root = _process('<div><p>Text</p></div>');
      final contentRoot = root
          .querySelector('.${HtmlConstants.kavitaWrapperClass}')!
          .children
          .single;

      expect(
        contentRoot.attributes[HtmlConstants.scrollIdAttribute],
        '//body',
      );
      expect(
        root.querySelector('p')!.attributes[HtmlConstants.scrollIdAttribute],
        '//body/p[1]',
      );
    });

    test('does not write a scroll id to a synthetic wrapper', () {
      final root = _process('<div><p>Text</p></div>');
      final wrapper = root.querySelector(
        '.${HtmlConstants.kavitaWrapperClass}',
      )!;

      expect(
        wrapper.attributes.containsKey(HtmlConstants.scrollIdAttribute),
        isFalse,
      );
    });

    test('keeps nested paths relative to the content root', () {
      final root = _process('<div><section><p>Text</p></section></div>');

      expect(
        root.querySelector('p')!.attributes[HtmlConstants.scrollIdAttribute],
        '//body/section[1]/p[1]',
      );
    });

    test('uses an id shortcut when the element has an id', () {
      final root = _process('<div><p id="note">Text</p></div>');

      expect(
        root.querySelector('p')!.attributes[HtmlConstants.scrollIdAttribute],
        'id("note")',
      );
    });

    test('indexes multiple top-level elements under body', () {
      final root = _process('<p>One</p><p>Two</p>');
      final paragraphs = root.querySelectorAll('p');

      expect(
        root
            .querySelector('.${HtmlConstants.kavitaWrapperClass}')!
            .attributes[HtmlConstants.scrollIdAttribute],
        '//body',
      );
      expect(
        paragraphs[0].attributes[HtmlConstants.scrollIdAttribute],
        '//body/p[1]',
      );
      expect(
        paragraphs[1].attributes[HtmlConstants.scrollIdAttribute],
        '//body/p[2]',
      );
    });
  });
}

dom.DocumentFragment _process(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [ScrollIdOperation()],
  ).process();
}
