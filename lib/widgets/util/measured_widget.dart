import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that measures its child's natural (unconstrained) height and
/// reports it via [onSizeMeasured], while constraining itself to the parent's
/// bounds so it never causes a RenderFlex overflow.
class MeasuredWidget extends SingleChildRenderObjectWidget {
  final ValueChanged<Size>? onSizeMeasured;

  const MeasuredWidget({
    super.key,
    required super.child,
    this.onSizeMeasured,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderMeasuredWidget(onSizeMeasured: onSizeMeasured);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasuredWidget renderObject,
  ) {
    renderObject.onSizeMeasured = onSizeMeasured;
  }
}

class RenderMeasuredWidget extends RenderProxyBox {
  ValueChanged<Size>? onSizeMeasured;

  RenderMeasuredWidget({this.onSizeMeasured});

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child!.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );

    final naturalSize = child!.size;
    onSizeMeasured?.call(naturalSize);
    size = constraints.constrain(naturalSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => super.paint(context, offset),
    );
  }
}
