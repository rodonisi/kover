import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/extensions/element.dart';
import 'package:kover/utils/extensions/epub_page_preprocessor.dart';

void main() {
  group('kavitaXPath', () {
    // A book page as the server serves it: the body wrapped in a div.
    Element page() {
      final root = DocumentFragment.html(
        '<div class="calibre"><style>p {}</style>'
        '<h1>Title</h1>'
        '<p>one</p>'
        '<div><p>two</p><p>three <em>four</em></p></div>'
        '<p>five</p>'
        '<div id="Chap1"><div><p>six</p></div></div>'
        '</div>',
      ).preprocessForRender();
      return root.children.single;
    }

    Element find(Element root, String text) => root
        .querySelectorAll('*')
        .lastWhere((element) => element.text.trim() == text);

    test('counts same-tag siblings from the page body', () {
      final root = page();

      expect(find(root, 'Title').kavitaXPath(), '//body/h1[1]');
      expect(find(root, 'one').kavitaXPath(), '//body/p[1]');
      expect(find(root, 'three four').kavitaXPath(), '//body/div[1]/p[2]');
      expect(find(root, 'four').kavitaXPath(), '//body/div[1]/p[2]/em[1]');
      expect(find(root, 'five').kavitaXPath(), '//body/p[2]');
    });

    test('starts from the nearest element with an id', () {
      final root = page();

      expect(find(root, 'six').kavitaXPath(), 'id("Chap1")/div[1]/p[1]');
      expect(root.querySelector('#Chap1')!.kavitaXPath(), 'id("Chap1")');
    });

    test('has no path for the body and what is around it', () {
      final root = page();
      final body = root.querySelector('.calibre')!;

      expect(body.kavitaXPath(), isNull);
      expect(root.kavitaXPath(), isNull);
      expect(Element.tag('p').kavitaXPath(), isNull);
    });
  });
}
