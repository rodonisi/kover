import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks the subtree of a tappable region, such as a link or annotation.
///
/// [OverlayGestures] looks for [RenderLinkHitRegion] in the hit-test path and
/// stays out of the gesture arena when a pointer lands on the region, letting
/// its recognizer handle the tap.
class LinkHitRegion extends SingleChildRenderObjectWidget {
  const new({super.key, required super.child});

  @override
  RenderLinkHitRegion createRenderObject(BuildContext context) =>
      RenderLinkHitRegion();
}

class RenderLinkHitRegion extends RenderProxyBox {}
