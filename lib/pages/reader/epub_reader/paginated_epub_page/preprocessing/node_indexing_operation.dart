import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

/// Assigns a 0-based preorder index to every element in the tree.
///
/// The index is written to [HtmlConstants.nodeIndexAttribute]. Indexing runs in
/// [finish], after operations that inject elements, so injected nodes receive
/// an index too.
final class NodeIndexingOperation extends EpubPagePreprocessorOperation {
  var _nextIndex = 0;

  @override
  void start(dom.DocumentFragment root) {
    _nextIndex = 0;
  }

  @override
  void finish(dom.DocumentFragment root) {
    _index(root);
  }

  void _index(dom.Node node) {
    if (node is dom.Element) {
      node.attributes[HtmlConstants.nodeIndexAttribute] = '${_nextIndex++}';
    }

    for (final child in node.nodes) {
      _index(child);
    }
  }
}
