import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/element.dart';

/// Writes each element's Kavita-compatible XPath to
/// [HtmlConstants.scrollIdAttribute].
final class ScrollIdOperation extends EpubPagePreprocessorOperation {
  dom.Element? _bodyRoot;

  @override
  void start(dom.DocumentFragment root) {
    final wrapper = root.children
        .where(
          (element) =>
              element.classes.contains(HtmlConstants.koverWrapperClass),
        )
        .firstOrNull;
    if (wrapper == null) {
      _bodyRoot = null;
      return;
    }

    // Kavita returns the body contents inside a single content element.
    // Treat that element as the body so persisted paths match `//body/...`.
    _bodyRoot = wrapper.children.length == 1
        ? wrapper.children.single
        : wrapper;
  }

  @override
  void enter(dom.Element element) {
    final xpath = element.xpath();
    if (_bodyRoot case final bodyRoot?) {
      element.attributes[HtmlConstants.scrollIdAttribute] =
          xpath.startsWith('id(') ? xpath : _bodyXpath(element, bodyRoot);
      return;
    }

    element.attributes[HtmlConstants.scrollIdAttribute] = xpath;
  }

  String _bodyXpath(dom.Element element, dom.Element bodyRoot) {
    if (identical(element, bodyRoot)) return '//body';

    final elementPath = element.xpath(pureXPath: true);
    final bodyPath = bodyRoot.xpath(pureXPath: true);
    final prefix = '$bodyPath/';
    if (!elementPath.startsWith(prefix)) return element.xpath();

    return '//body/${elementPath.substring(prefix.length)}';
  }
}
