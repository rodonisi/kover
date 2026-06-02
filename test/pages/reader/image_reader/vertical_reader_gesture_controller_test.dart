import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';

void main() {
  group('VerticalReaderGestureController', () {
    test('horizontal pan stops at the scaled viewport edge', () {
      final controller = _createController();

      controller.zoomViewport(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
        visualScrollOffset: 0,
      );
      controller.panHorizontally(200);

      expect(controller.translation, const Offset(150, 0));
    });

    test('zoom preserves horizontal focal point', () {
      final controller = _createController();

      controller.zoomViewport(
        scaleFactor: 2,
        focalPoint: const Offset(225, 150),
        focalPointDelta: Offset.zero,
        visualScrollOffset: 0,
      );

      expect(controller.scale, 2);
      expect(controller.translation, const Offset(-75, 0));
    });

    test(
      'zoom returns visual scroll offset preserving vertical focal point',
      () {
        final controller = _createController();

        final visualScrollOffset = controller.zoomViewport(
          scaleFactor: 2,
          focalPoint: const Offset(150, 225),
          focalPointDelta: Offset.zero,
          visualScrollOffset: 100,
        );

        expect(visualScrollOffset, 275);
      },
    );

    test('scaled viewport overflow is exposed as scroll padding', () {
      final controller = _createController();

      controller.zoomViewport(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
        visualScrollOffset: 0,
      );

      expect(controller.verticalScrollPadding, 75);
      expect(controller.translation.dy, 0);
    });
  });
}

VerticalReaderGestureController _createController() {
  return VerticalReaderGestureController()
    ..configureViewport(const Size(300, 300));
}
