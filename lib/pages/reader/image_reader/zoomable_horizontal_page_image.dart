import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A single horizontal-reader page: pinch-to-zoom and single-finger pan via
/// [InteractiveViewer].
///
/// While zoomed it reports via [onZoomChanged] so the parent [PageView] can
/// disable its scroll physics (letting panning own the single-finger gesture);
/// drag overflow and remaining velocity at a horizontal edge are forwarded to
/// the parent [PageView]'s controller.
class ZoomableHorizontalPageImage extends HookWidget {
  final Widget child;
  final PageController outerController;
  final ValueChanged<bool> onZoomChanged;

  /// Test seam: when omitted an internal controller is created.
  final TransformationController? transformationController;

  const ZoomableHorizontalPageImage({
    super.key,
    required this.child,
    required this.outerController,
    required this.onZoomChanged,
    this.transformationController,
  });

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _edgeTolerance = 0.5;

  @override
  Widget build(BuildContext context) {
    // Always create the hooked controller so hook order stays stable; prefer
    // an injected one (test seam) when provided.
    final hookController = useTransformationController();
    final controller = transformationController ?? hookController;

    final gestureIncludedPinch = useRef(false);
    final lastFocalX = useRef<double?>(null);
    final lastTranslationX = useRef<double?>(null);

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

        void scrollOuterByDragDelta(
          double dragDelta, {
          bool ballistic = false,
        }) {
          if (!outerController.hasClients) {
            return;
          }

          final position = outerController.position;
          final scrollDelta = axisDirectionIsReversed(position.axisDirection)
              ? dragDelta
              : -dragDelta;

          if (ballistic && position is ScrollPositionWithSingleContext) {
            position.goBallistic(scrollDelta);
          } else if (!ballistic && scrollDelta.abs() > _edgeTolerance) {
            outerController.jumpTo(
              (position.pixels + scrollDelta)
                  .clamp(position.minScrollExtent, position.maxScrollExtent)
                  .toDouble(),
            );
          }
        }

        void handleInteractionStart(ScaleStartDetails details) {
          gestureIncludedPinch.value = details.pointerCount >= 2;
          lastFocalX.value = details.localFocalPoint.dx;
          lastTranslationX.value = controller.value.getTranslation().x;
        }

        void handleInteractionUpdate(ScaleUpdateDetails details) {
          final previousFocalX = lastFocalX.value;
          final previousTranslationX = lastTranslationX.value;
          final currentTranslationX = controller.value.getTranslation().x;

          if (details.pointerCount >= 2) {
            gestureIncludedPinch.value = true;
          }

          final scale = controller.value.getMaxScaleOnAxis();
          if (scale > _minScale + 1e-3 &&
              previousFocalX != null &&
              previousTranslationX != null &&
              details.pointerCount == 1 &&
              !gestureIncludedPinch.value) {
            final focalDelta = details.localFocalPoint.dx - previousFocalX;
            final minTx = viewportWidth * (1 - scale);

            if ((previousTranslationX <= minTx + _edgeTolerance &&
                    focalDelta < 0) ||
                (previousTranslationX >= -_edgeTolerance && focalDelta > 0)) {
              scrollOuterByDragDelta(focalDelta);
            }
          }

          lastFocalX.value = details.localFocalPoint.dx;
          lastTranslationX.value = currentTranslationX;
        }

        void handleInteractionEnd(ScaleEndDetails details) {
          final endedAfterPinch = gestureIncludedPinch.value;
          gestureIncludedPinch.value = false;
          lastFocalX.value = null;
          lastTranslationX.value = null;

          if (endedAfterPinch) return;

          final matrix = controller.value;
          final scale = matrix.getMaxScaleOnAxis();
          if (scale <= _minScale + 1e-3) return; // not zoomed: PageView handles

          final tx = matrix.getTranslation().x;
          final vx = details.velocity.pixelsPerSecond.dx;
          final minTx = viewportWidth * (1 - scale); // right edge reached

          if ((tx <= minTx + _edgeTolerance && vx < 0) ||
              (tx >= -_edgeTolerance && vx > 0)) {
            scrollOuterByDragDelta(vx, ballistic: true);
          }
        }

        return InteractiveViewer(
          minScale: _minScale,
          maxScale: _maxScale,
          transformationController: controller,
          onInteractionStart: handleInteractionStart,
          onInteractionUpdate: handleInteractionUpdate,
          onInteractionEnd: handleInteractionEnd,
          child: child,
        );
      },
    );
  }
}
