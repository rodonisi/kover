import 'package:html/dom.dart';

extension DocumentFragmentExtensions on DocumentFragment {
  /// Finds the first descendant whose [attribute] equals [value].
  ///
  /// Falls back to filtering when [value] cannot be embedded in a selector.
  Element? findByAttribute(String attribute, String value) {
    try {
      return querySelector('[$attribute="$value"]');
    } on FormatException {
      for (final element in querySelectorAll('[$attribute]')) {
        if (element.attributes[attribute] == value) return element;
      }

      return null;
    }
  }

  String? paragraphScrollId() {
    final p = querySelectorAll('p')
        .where(
          (element) => element.hasText,
        )
        .firstOrNull;

    return p?.attributes['scroll-id'];
  }
}

extension NodeExtensions on Node {
  bool get hasVisibleNodes {
    return isTextOrImage || nodes.any((node) => node.hasVisibleNodes);
  }

  bool get hasText {
    return (this is Text && text != null && text!.trim().isNotEmpty) ||
        (this is Element && nodes.any((node) => node.hasText));
  }

  bool get isTextOrImage {
    return (this is Text && text != null && text!.trim().isNotEmpty) ||
        (this is Element &&
            _imageTags.contains(
              (this as Element).localName,
            ));
  }

  static const _imageTags = {'img', 'svg'};
}
