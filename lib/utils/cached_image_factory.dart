import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CachedImageFactory extends WidgetFactory {
  // final BuildContext context;
  final Map<int, MemoryImage> _cache = {};
  final double? maxHeight;

  CachedImageFactory({this.maxHeight});

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
        fit: .fill,
      ),
    );
  }
}
