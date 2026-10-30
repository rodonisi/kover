import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Renders an anchor element and lets the harvest pass read its rect.
class EpubMeasureAnchor extends SingleChildRenderObjectWidget {
  const EpubMeasureAnchor({super.key, super.child});

  @override
  RenderEpubMeasureAnchor createRenderObject(BuildContext context) =>
      RenderEpubMeasureAnchor();
}

class RenderEpubMeasureAnchor extends RenderProxyBox {}
