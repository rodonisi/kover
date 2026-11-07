import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/utils/extensions/element.dart';
import 'package:kover/utils/constants/html_constants.dart';

final class ScrollIdOperation extends EpubPagePreprocessorOperation {
  @override
  void enter(dom.Element element) {
    element.attributes[HtmlConstants.scrollIdAttribute] = element.xpath();
  }
}
