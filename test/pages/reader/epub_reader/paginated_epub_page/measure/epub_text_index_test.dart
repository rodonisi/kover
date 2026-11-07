import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_text_index.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('EpubTextIndex', () {
    test('maps the synthetic text-indent before a leading anchor', () {
      final block = _block(
        '<p ${HtmlConstants.textIndentAttribute}>'
        '<a id="morson">Morson, Walter Augustus Ormsby</a>'
        '</p>',
      );
      final anchor = block.querySelector('a')!;
      final text = anchor.firstChild!;
      const plainText = '\uFFFC\uFFFCMorson, Walter Augustus Ormsby';

      final index = EpubTextIndex.build(
        block: block,
        blockElements: {block},
        whitespace: CssWhitespace.normal,
        plainText: plainText,
      );

      expect(index.positionAt(0)?.node, same(block));
      expect(index.positionAt(0)?.offset, 0);
      expect(index.positionAt(1)?.node, same(anchor));
      expect(index.positionAt(2)?.node, same(text));
      expect(index.positionAt(2)?.offset, 0);
      expect(index.positionAt(plainText.length - 1)?.node, same(text));
    });

    test('maps the synthetic text-indent before leaked leading anchors', () {
      final block = _block(
        '<p ${HtmlConstants.textIndentAttribute}>'
        '<a id="elliott"></a>'
        '<a id="morson">Morson</a>'
        '</p>',
      );
      final previous = block.querySelector('#elliott')!;
      final current = block.querySelector('#morson')!;
      final text = current.firstChild!;
      const plainText = '\uFFFC\uFFFC\uFFFCMorson';

      final index = EpubTextIndex.build(
        block: block,
        blockElements: {block},
        whitespace: CssWhitespace.normal,
        plainText: plainText,
      );

      expect(index.positionAt(0)?.node, same(block));
      expect(index.positionAt(1)?.node, same(previous));
      expect(index.positionAt(2)?.node, same(current));
      expect(index.positionAt(3)?.node, same(text));
      expect(index.positionAt(3)?.offset, 0);
    });

    test('maps the synthetic text-indent before plain text', () {
      final block = _block(
        '<p ${HtmlConstants.textIndentAttribute}>Alpha</p>',
      );
      final text = block.firstChild!;
      const plainText = '\uFFFCAlpha';

      final index = EpubTextIndex.build(
        block: block,
        blockElements: {block},
        whitespace: CssWhitespace.normal,
        plainText: plainText,
      );

      expect(index.positionAt(0)?.node, same(block));
      expect(index.positionAt(1)?.node, same(text));
      expect(index.positionAt(1)?.offset, 0);
    });

    test('maps a leading anchor when there is no text-indent', () {
      final block = _block('<p><a id="morson">Morson</a></p>');
      final anchor = block.querySelector('a')!;
      final text = anchor.firstChild!;
      const plainText = '\uFFFCMorson';

      final index = EpubTextIndex.build(
        block: block,
        blockElements: {block},
        whitespace: CssWhitespace.normal,
        plainText: plainText,
      );

      expect(index.positionAt(0)?.node, same(anchor));
      expect(index.positionAt(1)?.node, same(text));
      expect(index.positionAt(1)?.offset, 0);
    });

    test('maps nested inline text after a leading anchor', () {
      final block = _block(
        '<p ${HtmlConstants.textIndentAttribute}>'
        '<a id="morson"></a>'
        '<span class="bold"><span style="font-size: larger">'
        'Morson, Walter Augustus Ormsby'
        '</span></span>, Barrister'
        '</p>',
      );
      final anchor = block.querySelector('#morson')!;
      final name = block.querySelector('span span')!.firstChild!;
      const plainText = '\uFFFC\uFFFCMorson, Walter Augustus Ormsby, Barrister';

      final index = EpubTextIndex.build(
        block: block,
        blockElements: {block},
        whitespace: CssWhitespace.normal,
        plainText: plainText,
      );

      expect(index.positionAt(0)?.node, same(block));
      expect(index.positionAt(1)?.node, same(anchor));
      expect(index.positionAt(2)?.node, same(name));
      expect(index.positionAt(2)?.offset, 0);
    });
  });
}

dom.Element _block(String html) {
  return dom.DocumentFragment.html(html).querySelector('p')!;
}
