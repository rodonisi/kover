import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';

const _zoomableKey = ValueKey('zoomable-horizontal-page-image');
const _testChild = SizedBox(width: 300, height: 300);

void main() {
  testWidgets('pinch zooms and reports the zoom state', (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final pageController = PageController();
    addTearDown(pageController.dispose);
    var zoomed = false;

    await tester.pumpWidget(
      _host(
        controller: controller,
        pageController: pageController,
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
    final pageController = PageController();
    addTearDown(pageController.dispose);
    var reportedZoomed = false;

    await tester.pumpWidget(
      _host(
        controller: controller,
        pageController: pageController,
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

  testWidgets('drag overflow at the right edge scrolls the outer PageView', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(-300);
    addTearDown(controller.dispose);
    final pageController = PageController(initialPage: 1);
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      _pagedHost(controller: controller, pageController: pageController),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_zoomableKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(pageController.offset, greaterThan(300));
    expect(controller.value.getTranslation().x, closeTo(-300, 1e-6));

    await gesture.up();
  });

  testWidgets(
    'inward drag at the right edge pans the image, not the PageView',
    (
      tester,
    ) async {
      final controller = TransformationController()..value = _zoomedAt(-300);
      addTearDown(controller.dispose);
      final pageController = PageController(initialPage: 1);
      addTearDown(pageController.dispose);

      await tester.pumpWidget(
        _pagedHost(controller: controller, pageController: pageController),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_zoomableKey)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(pageController.offset, closeTo(300, 1e-6));
      expect(controller.value.getTranslation().x, greaterThan(-300));

      await gesture.up();
    },
  );

  testWidgets('horizontal drag while zoomed pans before turning pages', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(-150);
    addTearDown(controller.dispose);
    final pageController = PageController(initialPage: 1);
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      _pagedHost(controller: controller, pageController: pageController),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_zoomableKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(pageController.offset, closeTo(300, 1e-6));
    expect(controller.value.getTranslation().x, lessThan(-150));

    await gesture.up();
  });

  testWidgets('remaining velocity at the right edge is passed to PageView', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(-300);
    addTearDown(controller.dispose);
    final pageController = PageController(initialPage: 1);
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      _pagedHost(controller: controller, pageController: pageController),
    );
    await tester.pump();

    await tester.fling(
      find.byKey(_zoomableKey),
      const Offset(-150, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(pageController.page, closeTo(2, 1e-6));
  });

  testWidgets('overflow drag respects a reversed outer PageView', (
    tester,
  ) async {
    final controller = TransformationController()..value = _zoomedAt(0);
    addTearDown(controller.dispose);
    final pageController = PageController(initialPage: 1);
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      _pagedHost(
        controller: controller,
        pageController: pageController,
        reverse: true,
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_zoomableKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(pageController.offset, greaterThan(300));
    expect(controller.value.getTranslation().x, closeTo(0, 1e-6));

    await gesture.up();
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
  required PageController pageController,
  ValueChanged<bool>? onZoomChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: ZoomableHorizontalPageImage(
            key: _zoomableKey,
            outerController: pageController,
            onZoomChanged: onZoomChanged ?? (_) {},
            transformationController: controller,
            child: _testChild,
          ),
        ),
      ),
    ),
  );
}

Widget _pagedHost({
  required TransformationController controller,
  required PageController pageController,
  bool reverse = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: PageView.builder(
            controller: pageController,
            reverse: reverse,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              if (index != 1) {
                return const SizedBox.expand();
              }

              return ZoomableHorizontalPageImage(
                key: _zoomableKey,
                outerController: pageController,
                onZoomChanged: (_) {},
                transformationController: controller,
                child: _testChild,
              );
            },
          ),
        ),
      ),
    ),
  );
}
