import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks the subtree of a tappable link.
///
/// [OverlayGestures] looks for [RenderLinkHitRegion] in the hit-test path and
/// stays out of the gesture arena when a pointer lands on a link, letting the
/// link recognizer handle the tap.
class LinkHitRegion extends SingleChildRenderObjectWidget {
  const LinkHitRegion({super.key, required super.child});

  @override
  RenderLinkHitRegion createRenderObject(BuildContext context) =>
      RenderLinkHitRegion();
}

class RenderLinkHitRegion extends RenderProxyBox {}
