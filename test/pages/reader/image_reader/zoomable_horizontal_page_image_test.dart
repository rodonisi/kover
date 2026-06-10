import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';

// A 1x1 transparent PNG so [Image.memory] has decodable bytes.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAen63NgAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('pinch zooms and reports the zoom state', (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    var zoomed = false;

    await tester.pumpWidget(
      _host(
        controller: controller,
        onZoomChanged: (value) => zoomed = value,
      ),
    );
    await tester.pump();

    final pointer1 = await tester.startGesture(const Offset(120, 150));
    final pointer2 = await tester.startGesture(const Offset(180, 150));
    await pointer1.moveBy(const Offset(-80, 0));
    await pointer2.moveBy(const Offset(80, 0));
    await tester.pump();
    await pointer1.up();
    await pointer2.up();
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));
    expect(zoomed, isTrue);
  });

  testWidgets('single-finger drag at base scale neither zooms nor pans', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    var reportedZoomed = false;

    await tester.pumpWidget(
      _host(
        controller: controller,
        onZoomChanged: (value) => reportedZoomed |= value,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(ZoomableHorizontalPageImage),
      const Offset(120, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), 1.0);
    expect(controller.value.getTranslation().x, closeTo(0.0, 1e-6));
    expect(reportedZoomed, isFalse);
  });

  testWidgets('fling past the right edge requests the next page (+1)', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(-300);
    addTearDown(controller.dispose);
    int? edge;

    await tester.pumpWidget(
      _host(controller: controller, onEdgeFling: (value) => edge = value),
    );
    await tester.pump();

    await tester.fling(
      find.byType(ZoomableHorizontalPageImage),
      const Offset(-150, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(edge, 1);
  });

  testWidgets('fling past the left edge requests the previous page (-1)', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(0);
    addTearDown(controller.dispose);
    int? edge;

    await tester.pumpWidget(
      _host(controller: controller, onEdgeFling: (value) => edge = value),
    );
    await tester.pump();

    await tester.fling(
      find.byType(ZoomableHorizontalPageImage),
      const Offset(150, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(edge, -1);
  });

  testWidgets('slow drag to the edge does not turn the page', (tester) async {
    final controller = TransformationController()..value = _zoomedAt(-300);
    addTearDown(controller.dispose);
    int? edge;

    await tester.pumpWidget(
      _host(controller: controller, onEdgeFling: (value) => edge = value),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(ZoomableHorizontalPageImage),
      const Offset(-60, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();

    expect(edge, isNull);
  });
}

// Scale 2x with the given horizontal translation, for a 300px-wide viewport
// the pan range is [-300, 0]: 0 == left edge, -300 == right edge.
Matrix4 _zoomedAt(double translationX) {
  final matrix = Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0);
  matrix.setTranslationRaw(translationX, 0, 0);
  return matrix;
}

Widget _host({
  required TransformationController controller,
  ValueChanged<bool>? onZoomChanged,
  ValueChanged<int>? onEdgeFling,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: ZoomableHorizontalPageImage(
            bytes: _pngBytes,
            fit: BoxFit.contain,
            onZoomChanged: onZoomChanged ?? (_) {},
            onEdgeFling: onEdgeFling ?? (_) {},
            transformationController: controller,
          ),
        ),
      ),
    ),
  );
}
