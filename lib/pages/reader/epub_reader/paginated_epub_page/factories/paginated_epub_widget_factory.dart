import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

/// A [WidgetFactory] that adjusts rendering for paginated EPUB content.
class PaginatedEpubWidgetFactory({
  final Size viewport = const Size(double.infinity, double.infinity),
}) extends WidgetFactory {
  @override
  StylesMap? customStylesBuilder(dom.Element element) {
    final styles = Map<String, String>.of(
      super.customStylesBuilder(element) ?? const {},
    );
    if (element.localName != 'img') return styles;

    final width = double.tryParse(element.attributes['width'] ?? '');
    final height = double.tryParse(element.attributes['height'] ?? '');
    if (width == null || height == null) return styles;

    final fitted = _fit(Size(width, height));
    return styles
      ..['width'] = '${fitted.width}px'
      ..['height'] = '${fitted.height}px';
  }

  Size _fit(Size size) {
    if (size.isEmpty) return size;

    final widthLimit = viewport.width.isFinite ? viewport.width : size.width;
    final heightLimit = viewport.height.isFinite
        ? viewport.height
        : size.height;

    final scale = math.min(
      1.0,
      math.min(widthLimit / size.width, heightLimit / size.height),
    );

    return Size(size.width * scale, size.height * scale);
  }
}
