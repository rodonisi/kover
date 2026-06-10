import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A single horizontal-reader page: pinch-to-zoom and single-finger pan via
/// [InteractiveViewer].
///
/// While zoomed it reports via [onZoomChanged] so the parent [PageView] can
/// disable its scroll physics (letting panning own the single-finger gesture);
/// a fling past a horizontal edge requests a page turn via [onEdgeFling].
class ZoomableHorizontalPageImage extends HookWidget {
  final Uint8List bytes;
  final BoxFit fit;
  final ValueChanged<bool> onZoomChanged;

  /// +1 when flung past the right edge, -1 when flung past the left edge.
  final ValueChanged<int> onEdgeFling;

  /// Test seam: when omitted an internal controller is created.
  final TransformationController? transformationController;

  const ZoomableHorizontalPageImage({
    super.key,
    required this.bytes,
    required this.fit,
    required this.onZoomChanged,
    required this.onEdgeFling,
    this.transformationController,
  });

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _flingVelocity = 400.0;

  @override
  Widget build(BuildContext context) {
    // Always create the hooked controller so hook order stays stable; prefer
    // an injected one (test seam) when provided.
    final hookController = useTransformationController();
    final controller = transformationController ?? hookController;

    // Pointer count from the last scale update. A two-finger pan should not
    // turn the page on an edge fling; only a single-finger swipe should.
    final lastPointerCount = useRef(1);

    useEffect(() {
      var wasZoomed = false;
      void onChange() {
        final zoomed = controller.value.getMaxScaleOnAxis() > _minScale + 1e-3;
        if (zoomed != wasZoomed) {
          wasZoomed = zoomed;
          onZoomChanged(zoomed);
        }
      }

      controller.addListener(onChange);
      return () => controller.removeListener(onChange);
    }, [controller]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;

        void handleInteractionEnd(ScaleEndDetails details) {
          if (lastPointerCount.value >= 2) return; // two-finger pan: no turn
          final matrix = controller.value;
          final scale = matrix.getMaxScaleOnAxis();
          if (scale <= _minScale + 1e-3) return; // not zoomed: PageView handles

          final tx = matrix.getTranslation().x;
          final vx = details.velocity.pixelsPerSecond.dx;
          final minTx = viewportWidth * (1 - scale); // right edge reached

          if (tx <= minTx + 0.5 && vx < -_flingVelocity) {
            onEdgeFling(1); // flung past right edge
          } else if (tx >= -0.5 && vx > _flingVelocity) {
            onEdgeFling(-1); // flung past left edge
          }
        }

        return InteractiveViewer(
          minScale: _minScale,
          maxScale: _maxScale,
          transformationController: controller,
          onInteractionUpdate: (d) => lastPointerCount.value = d.pointerCount,
          onInteractionEnd: handleInteractionEnd,
          child: Image.memory(bytes, fit: fit),
        );
      },
    );
  }
}
