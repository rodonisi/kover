import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/breakpoints.dart';

void main() {
  group('Breakpoints.update', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer.test();
    });

    tearDown(() => container.dispose());

    Breakpoint update(double width) {
      container.read(breakpointsProvider.notifier).update(width);
      return container.read(breakpointsProvider);
    }

    test('starts compact', () {
      expect(container.read(breakpointsProvider), Breakpoint.compact);
    });

    test('compact below compact', () {
      expect(update(LayoutBreakpoints.compact - 1), Breakpoint.compact);
    });

    test('medium between compact and medium', () {
      expect(update(LayoutBreakpoints.compact), Breakpoint.medium);
      expect(update(LayoutBreakpoints.medium - 1), Breakpoint.medium);
    });

    test('expanded between medium and expanded', () {
      expect(update(LayoutBreakpoints.medium), Breakpoint.expanded);
      expect(update(LayoutBreakpoints.expanded - 1), Breakpoint.expanded);
    });

    test('large between expanded and large', () {
      expect(update(LayoutBreakpoints.expanded), Breakpoint.large);
      expect(update(LayoutBreakpoints.large - 1), Breakpoint.large);
    });

    test('largest above large', () {
      expect(update(LayoutBreakpoints.large), Breakpoint.largest);
    });
  });

  group('BreakpointsWatcher', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer.test();
    });

    tearDown(() => container.dispose());

    Future<void> pumpWatcher(
      WidgetTester tester, {
      required double width,
      required EdgeInsets padding,
    }) async {
      tester.view.physicalSize = Size(width * 3, 393 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 393),
              padding: padding,
            ),
            child: const BreakpointsWatcher(child: SizedBox()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('landscape phone with notch insets stays medium', (
      tester,
    ) async {
      await pumpWatcher(
        tester,
        width: 852,
        padding: const EdgeInsets.symmetric(horizontal: 59),
      );
      expect(container.read(breakpointsProvider), Breakpoint.medium);
    });

    testWidgets('same width without insets is expanded', (tester) async {
      await pumpWatcher(tester, width: 852, padding: EdgeInsets.zero);
      expect(container.read(breakpointsProvider), Breakpoint.expanded);
    });

    testWidgets('portrait phone stays compact', (tester) async {
      await pumpWatcher(tester, width: 393, padding: EdgeInsets.zero);
      expect(container.read(breakpointsProvider), Breakpoint.compact);
    });
  });
}
