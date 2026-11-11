import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures_provider.dart';
import 'package:kover/widgets/util/link_hit_region.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a tagged link receives the tap instead of the overlay', (
    tester,
  ) async {
    var linkTaps = 0;
    var centerTaps = 0;
    final linkKey = GlobalKey();

    await tester.pumpWidget(
      _buildApp(
        onCenterTap: () => centerTaps++,
        content: Center(
          child: LinkHitRegion(
            child: GestureDetector(
              key: linkKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => linkTaps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(linkKey));
    await tester.pumpAndSettle();

    expect(linkTaps, 1);
    expect(centerTaps, 0);
  });

  testWidgets('an inline link span receives the tap instead of the overlay', (
    tester,
  ) async {
    var spanTaps = 0;
    var centerTaps = 0;
    final recognizer = TapGestureRecognizer()..onTap = () => spanTaps++;
    addTearDown(recognizer.dispose);

    await tester.pumpWidget(
      _buildApp(
        onCenterTap: () => centerTaps++,
        content: Center(
          child: RichText(
            textDirection: TextDirection.ltr,
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

    await tester.tap(_richText('inline link'));
    await tester.pumpAndSettle();

    expect(spanTaps, 1);
    expect(centerTaps, 0);
  });

  testWidgets('a non-link tap is handled by the overlay', (tester) async {
    var linkTaps = 0;
    var centerTaps = 0;
    final linkKey = GlobalKey();

    await tester.pumpWidget(
      _buildApp(
        onCenterTap: () => centerTaps++,
        content: Center(
          child: LinkHitRegion(
            child: GestureDetector(
              key: linkKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => linkTaps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 50));
    await tester.pumpAndSettle();

    expect(linkTaps, 0);
    expect(centerTaps, 1);
  });
}

Finder _richText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);

Widget _buildApp({
  required Widget content,
  required VoidCallback onCenterTap,
}) {
  final container = ProviderContainer.test(
    overrides: [
      overlayGesturesProvider(seriesId: 1).overrideWith(
        (ref) async => OverlayGesturesModel(
          navigationGestures: true,
          readDirection: ReadDirection.leftToRight,
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
