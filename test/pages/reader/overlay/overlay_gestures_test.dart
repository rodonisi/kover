import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures_provider.dart';
import 'package:kover/widgets/util/link_hit_region.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'overlay_gestures_test.mocks.dart';

abstract class TapCallback {
  void call();
}

@GenerateNiceMocks([MockSpec<TapCallback>()])
void main() {
  late MockTapCallback linkTap;
  late MockTapCallback centerTap;

  setUp(() {
    linkTap = MockTapCallback();
    centerTap = MockTapCallback();
  });

  group('OverlayGestures', () {
    testWidgets('a tagged link receives the tap instead of the overlay', (
      tester,
    ) async {
      final linkKey = GlobalKey();
      await tester.pumpWidget(
        _buildApp(
          onCenterTap: centerTap.call,
          content: Center(
            child: LinkHitRegion(
              child: GestureDetector(
                key: linkKey,
                behavior: .opaque,
                onTap: linkTap.call,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(linkKey));
      await tester.pumpAndSettle();

      verify(linkTap.call()).called(1);
      verifyNever(centerTap.call());
    });

    testWidgets('an inline link span receives the tap instead of the overlay', (
      tester,
    ) async {
      final recognizer = TapGestureRecognizer()..onTap = linkTap.call;
      addTearDown(recognizer.dispose);

      await tester.pumpWidget(
        _buildApp(
          onCenterTap: centerTap.call,
          content: Center(
            child: RichText(
              textDirection: .ltr,
              text: TextSpan(
                text: 'inline link',
                recognizer: recognizer,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('inline link', findRichText: true));
      await tester.pumpAndSettle();

      verify(linkTap.call()).called(1);
      verifyNever(centerTap.call());
    });

    testWidgets('a non-link tap is handled by the overlay', (tester) async {
      final linkKey = GlobalKey();
      await tester.pumpWidget(
        _buildApp(
          onCenterTap: centerTap.call,
          content: Center(
            child: LinkHitRegion(
              child: GestureDetector(
                key: linkKey,
                behavior: .opaque,
                onTap: linkTap.call,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 50));
      await tester.pumpAndSettle();

      verifyNever(linkTap.call());
      verify(centerTap.call()).called(1);
    });
  });
}

Widget _buildApp({
  required Widget content,
  required VoidCallback onCenterTap,
}) {
  final container = ProviderContainer.test(
    overrides: [
      overlayGesturesProvider(seriesId: 1).overrideWith(
        (ref) async => OverlayGesturesModel(
          navigationGestures: true,
          readDirection: .leftToRight,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned.fill(
              child: OverlayGestures(
                seriesId: 1,
                onCenterTap: onCenterTap,
                onLeftTap: () {},
                onRightTap: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
