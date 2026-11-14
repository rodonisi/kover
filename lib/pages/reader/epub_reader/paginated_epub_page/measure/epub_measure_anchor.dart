import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A widget that serves as an anchor for measuring EPUB content.
class EpubMeasureAnchor extends SingleChildRenderObjectWidget {
  const EpubMeasureAnchor({super.key, super.child});

  @override
  RenderEpubMeasureAnchor createRenderObject(BuildContext context) =>
      RenderEpubMeasureAnchor();
}

class RenderEpubMeasureAnchor extends RenderProxyBox {}
