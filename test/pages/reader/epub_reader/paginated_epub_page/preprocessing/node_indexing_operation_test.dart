import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('NodeIndexingOperation', () {
    test('when entering elements, then assigns sequential indexes', () {
      final operation = NodeIndexingOperation();
      final div = dom.Element.tag('div');
      final p = dom.Element.tag('p');
      final span = dom.Element.tag('span');

      operation.enter(div);
      operation.enter(p);
      operation.enter(span);

      expect(_nodeIndex(div), '0');
      expect(_nodeIndex(p), '1');
      expect(_nodeIndex(span), '2');
    });

    test('when started, then resets the index', () {
      final operation = NodeIndexingOperation();
      operation.enter(dom.Element.tag('div'));
      operation.enter(dom.Element.tag('p'));

      operation.start(dom.DocumentFragment());

      final span = dom.Element.tag('span');
      operation.enter(span);

      expect(_nodeIndex(span), '0');
    });
  });
}

String? _nodeIndex(dom.Element element) {
  return element.attributes[HtmlConstants.nodeIndexAttribute];
}
