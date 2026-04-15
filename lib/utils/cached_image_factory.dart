import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CachedImageFactory extends WidgetFactory {
  // final BuildContext context;
  final Map<int, MemoryImage> _cache = {};

  CachedImageFactory();

  @override
  Widget? buildImageWidget(
    BuildTree meta,
    ImageSource src,
  ) {
    final bytes = bytesFromDataUri(src.url);

    if (bytes == null) {
      return super.buildImageWidget(meta, src);
    }

    final hash = Object.hash(src.url, src.url.length);

    final provider = _cache[hash] ??= MemoryImage(bytes);

    return Image(
      key: ValueKey(hash),
      image: provider,
      gaplessPlayback: true,
      fit: .fill,
    );
  }
}
