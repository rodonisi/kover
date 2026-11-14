import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

/// Renders an element and lets the harvest pass read its rect.
sealed class RenderEpubProbe extends RenderProxyBox {
  int nodeIndex;
  dom.Element element;

  new({required this.nodeIndex, required this.element});
}

/// Renders a block element and lets the harvest pass read its rect.
class const EpubBlockProbe({
  super.key,
  required final int nodeIndex,
  required final dom.Element element,
  super.child,
}) extends SingleChildRenderObjectWidget {
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

final class RenderEpubBlockProbe({
  required super.nodeIndex,
  required super.element,
}) extends RenderEpubProbe;

/// Renders an unsplittable leaf element and lets the harvest pass read its rect.
class const EpubLeafProbe({
  super.key,
  required final int nodeIndex,
  required final dom.Element element,
  super.child,
}) extends SingleChildRenderObjectWidget {
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

final class RenderEpubLeafProbe({
  required super.nodeIndex,
  required super.element,
}) extends RenderEpubProbe;

/// Renders a text element and lets the harvest pass read its rect.
class const EpubTextProbe({
  super.key,
  required final int nodeIndex,
  required final dom.Element element,
  required final CssWhitespace whitespace,
  super.child,
}) extends SingleChildRenderObjectWidget {
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

final class RenderEpubTextProbe({
  required super.nodeIndex,
  required super.element,
  required var CssWhitespace whitespace,
}) extends RenderEpubProbe;

/// Measures spacing retained when a split block is rendered on a subpage.
class const EpubPaddingProbe({
  super.key,
  required final EdgeInsetsGeometry padding,
  super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderEpubPaddingProbe createRenderObject(BuildContext context) {
    return RenderEpubPaddingProbe(
      padding: padding.resolve(Directionality.of(context)),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEpubPaddingProbe renderObject,
  ) {
    renderObject.padding = padding.resolve(Directionality.of(context));
  }
}

final class RenderEpubPaddingProbe extends RenderProxyBox {
  EdgeInsets padding;

  RenderEpubPaddingProbe({required this.padding});
}
