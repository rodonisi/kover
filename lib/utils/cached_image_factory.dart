import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CachedImageFactory extends WidgetFactory {
  final BuildContext context;

  CachedImageFactory(this.context);

  @override
  Widget? buildImageWidget(
    BuildTree meta,
    ImageSource src,
  ) {
    final bytes = bytesFromDataUri(src.url);

    if (bytes == null) {
      return super.buildImageWidget(meta, src);
    }

    final provider = MemoryImage(bytes);
    precacheImage(provider, context);

    return Image(
      image: provider,
      gaplessPlayback: true,
      fit: .fill,
    );
  }
}
