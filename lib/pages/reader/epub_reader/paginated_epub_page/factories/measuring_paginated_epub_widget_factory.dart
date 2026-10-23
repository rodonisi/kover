import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_block_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_leaf_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_text_probe.dart';
import 'package:kover/utils/html_constants.dart';

sealed class EpubFailure {
  const EpubFailure({required this.nodeIndex});

  final int nodeIndex;
}

class EpubImageFailure extends EpubFailure {
  const EpubImageFailure({required super.nodeIndex, required this.url});

  final String url;
}

/// A [WidgetFactory] used for measuring the epub content.
/// Wraps blocks, text and images in probes that report their size and position.
class MeasuringPaginatedEpubWidgetFactory({super.viewport})
    extends PaginatedEpubWidgetFactory {
  final failures = <EpubImageFailure>[];

  final BuildOp epubBlockProbeOp = .v2(
    alwaysRenderBlock: false,
    debugLabel: 'epub-block-probe',
    priority: 9999,
    onRenderBlock: (tree, placeholder) {
      final nodeIndex = _nodeIndex(tree.element);
      if (nodeIndex == null) return placeholder;

      return EpubBlockProbe(
        nodeIndex: nodeIndex,
        element: tree.element,
        child: placeholder,
      );
    },
  );

  @override
  void parse(BuildTree meta) {
    meta.register(epubBlockProbeOp);

    super.parse(meta);
  }

  @override
  Widget? buildText(
    BuildTree tree,
    InheritedProperties resolved,
    InlineSpan text,
  ) {
    final child = super.buildText(tree, resolved, text);
    if (child == null) return child;

    final nodeIndex = _nodeIndex(tree.element);
    if (nodeIndex == null) return child;

    return EpubTextProbe(
      nodeIndex: nodeIndex,
      element: tree.element,
      whitespace: resolved.get<CssWhitespace>() ?? CssWhitespace.normal,
      child: child,
    );
  }

  @override
  Widget? buildImageWidget(BuildTree meta, ImageSource src) {
    final nodeIndex = _nodeIndex(meta.element);
    if (nodeIndex == null) return super.buildImageWidget(meta, src);

    final size = _imageSize(src);
    if (size == null) {
      failures.add(EpubImageFailure(nodeIndex: nodeIndex, url: src.url));
      return EpubLeafProbe(
        nodeIndex: nodeIndex,
        element: meta.element,
        child: const SizedBox.shrink(),
      );
    }

    final fitted = _fit(size);
    final child = super.buildImageWidget(meta, src);

    return EpubLeafProbe(
      nodeIndex: nodeIndex,
      element: meta.element,
      child: SizedBox(
        width: fitted.width,
        height: fitted.height,
        child: child,
      ),
    );
  }

  Size? _imageSize(ImageSource src) {
    if (src.width != null && src.height != null) {
      return Size(src.width!, src.height!);
    }

    return null;
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

  static int? _nodeIndex(dom.Element element) {
    final indexAttr =
        element.attributes[HtmlConstants.nodeIndexAttribute] ?? '';
    return int.tryParse(indexAttr);
  }
}
