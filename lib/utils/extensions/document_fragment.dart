import 'package:html/dom.dart';

extension DocumentFragmentExtensions on DocumentFragment {
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
