import 'package:html/dom.dart';
import 'package:kover/utils/extensions/string.dart';
import 'package:kover/utils/html_constants.dart';

extension KavitaXPathExtension on Element {
  /// The XPath Kavita uses for this element of an epub page, as the web
  /// reader computes it: relative to the page body, which the server wraps
  /// in the outer div of the page, or to the nearest element with an id.
  /// Returns null for the body itself and for elements outside it.
  String? kavitaXPath() {
    final steps = <String>[];
    Element current = this;

    while (true) {
      final parent = current.parent;
      if (parent == null) return null;

      if (parent.classes.contains(HtmlConstants.koverWrapperClass)) {
        return steps.isEmpty ? null : '//body/${steps.reversed.join('/')}';
      }

      if (current.id.isNotEmpty) {
        steps.add('id("${current.id}")');
        return steps.reversed.join('/');
      }

      final sameTag = parent.children
          .where((sibling) => sibling.localName == current.localName)
          .toList();
      steps.add('${current.localName}[${sameTag.indexOf(current) + 1}]');
      current = parent;
    }
  }
}

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
      return 'id("${element.id}")'.cssEscaped;
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
