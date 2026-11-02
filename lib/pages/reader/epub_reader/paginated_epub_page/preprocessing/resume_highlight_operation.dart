import 'package:html/dom.dart' as dom;
import 'package:kover/utils/html_constants.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';

/// Marks the resume paragraph with a class so the stylesheet can highlight it.
final class ResumeHighlightOperation extends EpubPagePreprocessorOperation {
  ResumeHighlightOperation({
    required this.scrollId,
    this.className = HtmlConstants.resumeClass,
  });

  final String? scrollId;
  final String className;

  @override
  void enter(dom.Element element) {
    final scrollId = this.scrollId;
    if (scrollId == null) return;

    if (element.attributes[HtmlConstants.scrollIdAttribute] == scrollId) {
      element.classes.add(className);
    }
  }
}
