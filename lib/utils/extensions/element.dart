import 'package:html/dom.dart';

extension ScrollIdExtension on Element {
  /// Computes the XPath of this element relative to the root of the document.
  String xpath({bool pureXPath = false}) {
    var xpath = _getXPath(this, pureXPath: pureXPath);
    if (!xpath.startsWith('//') && !xpath.startsWith('id(')) {
      xpath = '//$xpath';
    }

    return xpath;
  }

  static String _getXPath(Element? element, {bool pureXPath = false}) {
    if (element == null || element.localName == null) {
      return '';
    }

    // Handle shortcuts (unless pureXPath is requested)
    if (!pureXPath && element.id.isNotEmpty) {
      return 'id("${element.id}")';
    }

    if (element.localName == 'body') {
      return 'body';
    }

    final parent = element.parent;
    if (parent == null) {
      return element.localName!.toLowerCase();
    }

    // Count same-tag siblings
    int siblingIndex = 1;
    final tagName = element.localName;

    for (var sibling in parent.children) {
      if (sibling == element) {
        break;
      }
      if (sibling.localName == tagName) {
        siblingIndex++;
      }
    }

    final currentPath = '${element.localName!.toLowerCase()}[$siblingIndex]';
    final parentPath = _getXPath(parent, pureXPath: pureXPath);

    return parentPath.isNotEmpty ? '$parentPath/$currentPath' : currentPath;
  }
}
