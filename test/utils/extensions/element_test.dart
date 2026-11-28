import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/element.dart';

void main() {
  group('xpath', () {
    test('computes relative to the Kavita content root', () {
      final root = dom.DocumentFragment.html(
        '<div class="${HtmlConstants.kavitaWrapperClass}">'
        '<div><p>Text</p></div></div>',
      );
      final contentRoot = root.querySelector(
        '.${HtmlConstants.kavitaWrapperClass}',
      )!;

      expect(contentRoot.children.single.xpath(), '//body');
      expect(contentRoot.querySelector('p')!.xpath(), '//body/p[1]');
      expect(contentRoot.xpath(), isNull);
    });
  });
}
