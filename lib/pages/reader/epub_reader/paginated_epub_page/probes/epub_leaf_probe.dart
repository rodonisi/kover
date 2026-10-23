import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:html/dom.dart' as dom;

/// Renders an unsplittable leaf element and lets the harvest pass read its rect.
class EpubLeafProbe extends SingleChildRenderObjectWidget {
  final int nodeIndex;
  final dom.Element element;

  const new({
    super.key,
    required this.nodeIndex,
    required this.element,
    super.child,
  });

  @override
  RenderEpubLeafProbe createRenderObject(BuildContext context) {
    return RenderEpubLeafProbe(nodeIndex: nodeIndex, element: element);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEpubLeafProbe renderObject,
  ) {
    renderObject
      ..nodeIndex = nodeIndex
      ..element = element;
  }
}

class RenderEpubLeafProbe extends RenderProxyBox {
  int nodeIndex;
  dom.Element element;

  new({required this.nodeIndex, required this.element});
}
