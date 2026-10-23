import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

/// Renders a text element and lets the harvest pass read its rect.
class EpubTextProbe extends SingleChildRenderObjectWidget {
  final int nodeIndex;
  final dom.Element element;
  final CssWhitespace whitespace;

  const new({
    super.key,
    required this.nodeIndex,
    required this.element,
    required this.whitespace,
    super.child,
  });

  @override
  RenderEpubTextProbe createRenderObject(BuildContext context) {
    return RenderEpubTextProbe(
      nodeIndex: nodeIndex,
      element: element,
      whitespace: whitespace,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEpubTextProbe renderObject,
  ) {
    renderObject
      ..nodeIndex = nodeIndex
      ..element = element
      ..whitespace = whitespace;
  }
}

class RenderEpubTextProbe extends RenderProxyBox {
  int nodeIndex;
  dom.Element element;
  CssWhitespace whitespace;

  new({
    required this.nodeIndex,
    required this.element,
    required this.whitespace,
  });
}
