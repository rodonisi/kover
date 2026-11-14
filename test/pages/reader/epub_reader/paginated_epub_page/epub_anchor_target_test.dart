import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';

void main() {
  group('EpubAnchorTarget', () {
    test('parses a same-page fragment', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html('<a href="#note">note</a>'),
      );

      expect(target?.page, isNull);
      expect(target?.part, 'note');
      expect(target?.externalUri, isNull);
    });

    test('parses backend page and part attributes', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html(
          '<a href="javascript:void(0)" '
          'kavita-page="8" kavita-part="page_8">chapter</a>',
        ),
      );

      expect(target?.page, 8);
      expect(target?.part, 'page_8');
    });

    test('prefers kavita-note-ref over the rewritten href', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html(
          '<a href="javascript:void(0)" '
          'kavita-note-ref="#_footnote_1">*</a>',
        ),
      );

      expect(target?.page, isNull);
      expect(target?.part, '_footnote_1');
    });

    test('parses external links', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html('<a href="https://example.com/path">external</a>'),
      );

      expect(target?.externalUri, Uri.parse('https://example.com/path'));
    });

    test('normalizes protocol-relative links', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html('<a href="//example.com/path">external</a>'),
      );

      expect(target?.externalUri, Uri.parse('https://example.com/path'));
    });

    test('ignores no-op javascript links', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html('<a href="javascript:void(0)">noop</a>'),
      );

      expect(target, isNull);
    });

    test('ignores non-anchor elements', () {
      final target = EpubAnchorTarget.fromElement(
        dom.Element.html('<span kavita-page="8">chapter</span>'),
      );

      expect(target, isNull);
    });
  });
}
