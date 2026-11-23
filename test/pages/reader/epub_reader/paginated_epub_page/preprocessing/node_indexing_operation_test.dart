import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('NodeIndexingOperation', () {
    test('when finishing, then assigns sequential indexes', () {
      final operation = NodeIndexingOperation();
      final root = dom.DocumentFragment.html('<div><p><span></span></p></div>');
      final div = root.querySelector('div')!;
      final p = root.querySelector('p')!;
      final span = root.querySelector('span')!;

      operation.start(root);
      operation.finish(root);

      expect(_nodeIndex(div), '0');
      expect(_nodeIndex(p), '1');
      expect(_nodeIndex(span), '2');
    });

    test('when started, then resets the index', () {
      final operation = NodeIndexingOperation();
      final root = dom.DocumentFragment.html('<div><p></p></div>');

      operation.start(root);
      operation.finish(root);
      operation.start(root);
      operation.finish(root);

      expect(_nodeIndex(root.querySelector('div')!), '0');
      expect(_nodeIndex(root.querySelector('p')!), '1');
    });
  });
}

String? _nodeIndex(dom.Element element) {
  return element.attributes[HtmlConstants.nodeIndexAttribute];
}
