import 'package:html/dom.dart' as dom;
import 'package:html/dom_parsing.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';

/// Performs a single depth-first walk over a document fragment and notifies
/// the registered [operations] for every element and text node.
final class EpubPageTreeWalker extends TreeVisitor {
  EpubPageTreeWalker(this.operations);

  final List<EpubPagePreprocessorOperation> operations;

  void walk(dom.DocumentFragment root) => visit(root);

  @override
  void visitElement(dom.Element node) {
    for (final operation in operations) {
      operation.enter(node);
    }

    visitChildren(node);

    for (final operation in operations.reversed) {
      operation.exit(node);
    }
  }

  @override
  void visitText(dom.Text node) {
    for (final operation in operations) {
      operation.text(node);
    }
  }
}
