import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';

class ZoomableVerticalScrollView extends HookWidget {
  final ScrollController scrollController;
  final VerticalReaderGestureController gestureController;
  final Widget child;

  const ZoomableVerticalScrollView({
    super.key,
    required this.scrollController,
    required this.gestureController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final gestureActive = useRef(false);
    final gestureIncludedPinch = useRef(false);
    final scrolledDuringGesture = useRef(false);
    final lastPointerCount = useRef(0);
    final lastScale = useRef(1.0);
    final lastFocalPoint = useRef(Offset.zero);
    final scheduledViewportSize = useRef<Size?>(null);
    final scheduledGestureController = useRef<VerticalReaderGestureController?>(
      null,
    );

    void scheduleViewportConfiguration(Size viewportSize) {
      if (viewportSize.isEmpty ||
          !viewportSize.width.isFinite ||
          !viewportSize.height.isFinite ||
          (scheduledViewportSize.value == viewportSize &&
              scheduledGestureController.value == gestureController)) {
        return;
      }

      scheduledViewportSize.value = viewportSize;
      scheduledGestureController.value = gestureController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        gestureController.configureViewport(viewportSize);
      });
    }

    void setVisualScrollOffset(double visualScrollOffset) {
      if (!scrollController.hasClients) return;

      final position = scrollController.position;
      final scaledMinScrollExtent =
          position.minScrollExtent * gestureController.scale;
      final scaledMaxScrollExtent =
          position.maxScrollExtent * gestureController.scale;
      final nextVisualScrollOffset = visualScrollOffset
          .clamp(
            scaledMinScrollExtent,
            scaledMaxScrollExtent,
          )
          .toDouble();
      final nextScrollOffset =
          nextVisualScrollOffset
              .clamp(scaledMinScrollExtent, scaledMaxScrollExtent)
              .toDouble() /
          gestureController.scale;

      if (nextScrollOffset != position.pixels) {
        position.jumpTo(nextScrollOffset);
        scrolledDuringGesture.value = true;
      }
    }

    void handlePointerDown(PointerDownEvent event) {
      if (scrollController.hasClients) {
        // Instantly halts any active ballistic scrolling the moment a finger
        // touches the screen
        final position = scrollController.position;
        position.jumpTo(position.pixels);
      }
    }

    void handleScaleStart(ScaleStartDetails details) {
      gestureActive.value = true;
      gestureIncludedPinch.value = details.pointerCount >= 2;
      scrolledDuringGesture.value = false;
      lastPointerCount.value = details.pointerCount;
      lastScale.value = 1.0;
      lastFocalPoint.value = details.localFocalPoint;

      if (scrollController.hasClients) {
        final position = scrollController.position;
        position.jumpTo(position.pixels);
      }
    }

    void scrollByVisualDelta(double visualDelta) {
      if (visualDelta == 0.0 || !scrollController.hasClients) return;

      final position = scrollController.position;
      setVisualScrollOffset(
        gestureController.visualScrollOffset(position.pixels) - visualDelta,
      );
    }

    void handleScaleUpdate(ScaleUpdateDetails details) {
      if (!gestureActive.value) return;

      final focalPoint = details.localFocalPoint;
      final focalPointDelta = focalPoint - lastFocalPoint.value;

      if (details.pointerCount >= 2) {
        gestureIncludedPinch.value = true;
        if (lastPointerCount.value == details.pointerCount &&
            scrollController.hasClients) {
          final position = scrollController.position;
          final nextVisualScrollOffset = gestureController.zoomViewport(
            scaleFactor: details.scale / lastScale.value,
            focalPoint: focalPoint,
            focalPointDelta: focalPointDelta,
            visualScrollOffset: gestureController.visualScrollOffset(
              position.pixels,
            ),
          );
          setVisualScrollOffset(nextVisualScrollOffset);
        }

        lastScale.value = details.scale;
        lastFocalPoint.value = focalPoint;
        lastPointerCount.value = details.pointerCount;
        return;
      }

      lastScale.value = details.scale;
      lastFocalPoint.value = focalPoint;
      lastPointerCount.value = details.pointerCount;

      if (gestureIncludedPinch.value) return;

      gestureController.panHorizontally(focalPointDelta.dx);
      scrollByVisualDelta(focalPointDelta.dy);
    }

    Future<void> handleScaleEnd(ScaleEndDetails details) async {
      if (!gestureActive.value) return;

      gestureActive.value = false;
      if (gestureIncludedPinch.value ||
          !scrolledDuringGesture.value ||
          !scrollController.hasClients) {
        return;
      }

      final position = scrollController.position;
      if (position is ScrollPositionWithSingleContext) {
        position.goBallistic(
          -details.velocity.pixelsPerSecond.dy / gestureController.scale,
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        scheduleViewportConfiguration(constraints.biggest);

        return Listener(
          onPointerDown: handlePointerDown,
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              scrollByVisualDelta(-pointerSignal.scrollDelta.dy);
              gestureController.panHorizontally(-pointerSignal.scrollDelta.dx);
            }
          },
          child: GestureDetector(
            behavior: .opaque,
            onScaleStart: handleScaleStart,
            onScaleUpdate: handleScaleUpdate,
            onScaleEnd: (details) => unawaited(handleScaleEnd(details)),
            child: ClipRect(
              child: AnimatedBuilder(
                animation: gestureController,
                child: IgnorePointer(child: child),
                builder: (context, child) {
                  return Transform.translate(
                    offset: gestureController.translation,
                    child: Transform.scale(
                      scale: gestureController.scale,
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
