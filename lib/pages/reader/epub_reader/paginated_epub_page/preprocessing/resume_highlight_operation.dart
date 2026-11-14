import 'package:html/dom.dart' as dom;
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';

/// Marks the resume paragraph with a class so the stylesheet can highlight it.
final class ResumeHighlightOperation({
  required final String? scrollId,
}) extends EpubPagePreprocessorOperation {
  @override
  void enter(dom.Element element) {
    final scrollId = this.scrollId;
    if (scrollId == null) return;

    if (element.attributes[HtmlConstants.scrollIdAttribute] == scrollId) {
      element.classes.add(HtmlConstants.resumeParagraphClass);
    }
  }
}
