import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_tree_walker.dart';
import 'package:kover/utils/html_constants.dart';

/// Applies an ordered set of operations during a single walk over [root].
///
/// When [operations] is omitted, the preprocessor only performs node indexing.
class EpubPagePreprocessor({
  required final dom.DocumentFragment html,
  required final List<EpubPagePreprocessorOperation> operations,
}) {
  /// Runs all operations and returns root.
  dom.DocumentFragment process() {
    final root = dom.DocumentFragment();
    final wrapper = dom.Element.tag('div')
      ..className =
          '${HtmlConstants.kavitaWrapperClass} ${HtmlConstants.koverWrapperClass}'
      ..append(html.clone(true));
    root.append(wrapper);
    final activeOperations = operations;

    for (final operation in activeOperations) {
      operation.start(root);
    }

    EpubPageTreeWalker(activeOperations).walk(root);

    for (final operation in activeOperations.reversed) {
      operation.finish(root);
    }

    return root;
  }
}
