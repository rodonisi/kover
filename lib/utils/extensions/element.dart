import 'package:html/dom.dart';
import 'package:kover/utils/constants/html_constants.dart';

extension ScrollIdExtension on Element {
  /// Computes the Kavita-compatible XPath for this element.
  ///
  /// Returns `null` for elements outside the Kavita content root.
  String? xpath() {
    final bodyRoot = _bodyRoot;
    if (bodyRoot == null) return null;

    final xpath = _getXPath(this, bodyRoot: bodyRoot);
    if (xpath == null) return null;
    if (!xpath.startsWith('//') && !xpath.startsWith('id(')) {
      return '//$xpath';
    }

    return xpath;
  }

  Element? get _bodyRoot {
    Element? wrapper;
    Element? current = this;
    while (current != null) {
      if (current.classes.contains(HtmlConstants.kavitaWrapperClass)) {
        wrapper = current;
      }
      current = current.parent;
    }

    if (wrapper == null) return null;
    return wrapper.children.length == 1 ? wrapper.children.single : wrapper;
  }

  static String? _getXPath(Element? element, {required Element bodyRoot}) {
    if (element == null || element.localName == null) {
      return null;
    }

    // Handle shortcuts.
    if (element.id.isNotEmpty) {
      return 'id("${element.id}")';
    }

    if (identical(element, bodyRoot) || element.localName == 'body') {
      return 'body';
    }

    final parent = element.parent;
    if (parent == null) {
      return null;
    }

    // Count same-tag siblings.
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
    final parentPath = _getXPath(parent, bodyRoot: bodyRoot);
    if (parentPath == null) return null;

    return '$parentPath/$currentPath';
  }
}
