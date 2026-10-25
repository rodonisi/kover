import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/utils/highlight_recognizer.dart';
import 'package:kover/utils/html_constants.dart';

class CachedImageFactory extends WidgetFactory {
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
