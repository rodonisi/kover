import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/epub_selection.dart';
import 'package:kover/utils/highlight_recognizer.dart';
import 'package:kover/utils/html_constants.dart';

class CachedImageFactory extends WidgetFactory {
  /// Block elements that usually hold text, tracked for the selection.
  static const _textBlockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'pre', //
    'dd', 'dt', 'figcaption', 'td', 'th', 'div',
  };

  static final _selectionBlock = BuildOp(
    alwaysRenderBlock: false,
    debugLabel: 'epub selection block',
    onRenderBlock: (tree, placeholder) {
      final scrollId = tree.element.attributes[HtmlConstants.scrollIdAttribute];
      if (scrollId == null) return placeholder;

      return placeholder.wrapWith(
        (context, child) =>
            EpubSelectionBlock(scrollId: scrollId, child: child),
      );
    },
  );

  final Map<int, MemoryImage> _cache = {};
  final double? maxHeight;

  CachedImageFactory({this.maxHeight});

  @override
  void parse(BuildTree meta) {
    final element = meta.element;
    const prefix = HtmlConstants.highlightIdPrefix;
    if (element.localName == HtmlConstants.highlightTag &&
        element.id.startsWith(prefix)) {
      final annotationId = int.tryParse(element.id.substring(prefix.length));
      if (annotationId != null) {
        meta.inherit(_highlightRecognizer, HighlightRecognizer(annotationId));
      }
    }

    if (_textBlockTags.contains(element.localName) &&
        element.attributes.containsKey(HtmlConstants.scrollIdAttribute)) {
      meta.register(_selectionBlock);
    }

    super.parse(meta);
  }

  /// Hands the highlight's recognizer down to the text spans inside it.
  static InheritedProperties _highlightRecognizer(
    InheritedProperties resolving,
    GestureRecognizer value,
  ) => resolving.copyWith<GestureRecognizer>(value: value);

  @override
  Widget? buildImageWidget(
    BuildTree meta,
    ImageSource src,
  ) {
    final bytes = bytesFromDataUri(src.url);

    if (bytes == null ||
        src.url.endsWith('.svg') ||
        src.url.startsWith('data:image/svg+xml')) {
      return super.buildImageWidget(meta, src);
    }

    final hash = Object.hash(src.url, src.url.length);

    final provider = _cache[hash] ??= MemoryImage(bytes);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: Image(
        key: ValueKey(hash),
        image: provider,
        gaplessPlayback: true,
        fit: .contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return SizedBox(
            height: src.height ?? maxHeight,
            width: src.width,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
