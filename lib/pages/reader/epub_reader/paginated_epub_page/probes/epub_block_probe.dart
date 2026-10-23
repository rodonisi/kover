import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:html/dom.dart' as dom;

/// Renders a block element and lets the harvest pass read its rect.
class EpubBlockProbe extends SingleChildRenderObjectWidget {
  final int nodeIndex;
  final dom.Element element;

  const new({
    super.key,
    required this.nodeIndex,
    required this.element,
    super.child,
  });

  @override
  RenderEpubBlockProbe createRenderObject(BuildContext context) {
    return RenderEpubBlockProbe(nodeIndex: nodeIndex, element: element);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEpubBlockProbe renderObject,
  ) {
    renderObject
      ..nodeIndex = nodeIndex
      ..element = element;
  }
}

class RenderEpubBlockProbe extends RenderProxyBox {
  int nodeIndex;
  dom.Element element;

  new({required this.nodeIndex, required this.element});
}
