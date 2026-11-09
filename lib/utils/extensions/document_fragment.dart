import 'package:html/dom.dart';
import 'package:kover/utils/extensions/string.dart';
import 'package:kover/utils/html_constants.dart';

extension DocumentFragmentExtensions on DocumentFragment {
  String? paragraphScrollId() {
    final p = querySelectorAll('p')
        .where(
          (element) => element.hasText,
        )
        .firstOrNull;

    return p?.attributes['scroll-id'];
  }

  /// Whether reading resumes on this subpage for the progress saved with
  /// [scrollId]. Progress stores the first paragraph of the visible subpage,
  /// so a split paragraph ending this subpage was saved from the next one,
  /// where it continues at the top.
  bool isResumePoint(String scrollId) {
    final element = querySelector(
      '[${HtmlConstants.scrollIdAttribute}="${scrollId.cssEscaped}"]',
    );
    if (element == null || !element.hasChildNodes()) return false;

    return !element.attributes.containsKey(
          HtmlConstants.splitParagraphAttribute,
        ) ||
        paragraphScrollId() == scrollId;
  }
}

extension NodeExtensions on Node {
  bool get hasVisibleNodes {
    return !isIndentSpan &&
        (isTextOrImage || nodes.any((node) => node.hasVisibleNodes));
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

  bool get isIndentSpan {
    return this is Element &&
        (this as Element).attributes.containsKey(
          HtmlConstants.textIndentSpanAttribute,
        );
  }

  static const _imageTags = {'img', 'svg'};
}
