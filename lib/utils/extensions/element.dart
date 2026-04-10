import 'package:html/dom.dart';
import 'package:kover/utils/html_constants.dart';

extension ScrollIdExtension on Element {
  /// Computes the XPath of this element relative to the root of the document.
  String get scrollId {
    final cached = attributes[HtmlConstants.scrollIdAttribute];
    if (cached != null) {
      return cached;
    }

    final List<String> paths = [];
    Element? current = this;

    Element? idParent;
    while (current != null && current.localName != null) {
      final String tagName = current.localName!;

      // If it's the root html element, just add it and break
      if (tagName.toLowerCase() == 'html') {
        break;
      }

      // Skip wrapper div with class " "
      if (tagName.toLowerCase() == 'div' &&
          current.attributes['class'] == ' ') {
        current = current.parent;
        continue;
      }

      // Stop at parent with id
      final String? parentId = current.attributes['id'];
      if (parentId != null && parentId.isNotEmpty) {
        idParent = current;
        break;
      }

      // Calculate index among siblings with the same tag name
      int index = 1;
      Element? sibling = current.previousElementSibling;
      while (sibling != null) {
        if (sibling.localName == tagName) {
          index++;
        }
        sibling = sibling.previousElementSibling;
      }

      // Always include index for consistency
      if (tagName.toLowerCase() == 'body' && index == 1) {
        paths.add(tagName);
      } else {
        paths.add('$tagName[$index]');
      }

      current = current.parent;
    }

    final pathString = paths.reversed.join('/');
    if (idParent != null) {
      return 'id(${idParent.attributes['id']!})/$pathString';
    }
    return '//$pathString';
  }
}
