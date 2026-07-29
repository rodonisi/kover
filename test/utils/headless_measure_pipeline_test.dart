import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/utils/headless_measure_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HeadlessMeasurePipeline pipeline;

  setUp(() {
    pipeline = HeadlessMeasurePipeline();
  });

  tearDown(() {
    pipeline.dispose();
  });

  test('measures target size synchronously', () {
    pipeline.attach(size: const Size(400, 800), devicePixelRatio: 1);

    final size = pipeline.measure(
      const Column(
        mainAxisSize: .min,
        children: [
          MeasureTarget(child: SizedBox(width: 100, height: 300)),
        ],
      ),
    );

    expect(size, const Size(100, 300));
  });

  test('natural content height is not clamped by the viewport', () {
    pipeline.attach(size: const Size(400, 800), devicePixelRatio: 1);

    final size = pipeline.measure(
      const Column(
        mainAxisSize: .min,
        children: [
          MeasureTarget(child: SizedBox(height: 9999)),
        ],
      ),
    );

    expect(size.height, 9999.0);
  });

  test('reconfiguration on viewport resize', () {
    pipeline.attach(size: const Size(400, 800), devicePixelRatio: 1);
    pipeline.attach(size: const Size(200, 400), devicePixelRatio: 1);

    final size = pipeline.measure(
      const Column(
        mainAxisSize: .min,
        children: [
          MeasureTarget(child: SizedBox(width: 999, height: 100)),
        ],
      ),
    );

    expect(size.width, 200.0);
  });

  test('repeated measures reuse the element tree', () {
    pipeline.attach(size: const Size(400, 800), devicePixelRatio: 1);

    const widget1 = Column(
      mainAxisSize: .min,
      children: [
        MeasureTarget(child: SizedBox(width: 100, height: 100)),
      ],
    );
    const widget2 = Column(
      mainAxisSize: .min,
      children: [
        MeasureTarget(child: SizedBox(width: 100, height: 250)),
      ],
    );

    final first = pipeline.measure(widget1);
    final second = pipeline.measure(widget2);
    final third = pipeline.measure(widget1);

    expect(first, const Size(100, 100));
    expect(second, const Size(100, 250));
    expect(third, const Size(100, 100));
  });

  test('build failure throws MeasureTreeBuildException', () {
    pipeline.attach(size: const Size(400, 800), devicePixelRatio: 1);

    // Swallow the FlutterError reported by the failed build so the test
    // binding does not flag it as an uncaught error.
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    expect(
      () => pipeline.measure(
        const Column(
          mainAxisSize: .min,
          children: [
            MeasureTarget(child: _ThrowingWidget()),
          ],
        ),
      ),
      throwsA(isA<MeasureTreeBuildException>()),
    );
    expect(reported, isNotEmpty);
  });
}

class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('boom');
  }
}
