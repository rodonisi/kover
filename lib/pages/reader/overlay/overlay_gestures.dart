import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/mapping/enums/read_direction.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures_provider.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/link_hit_region.dart';
import 'package:material_ui/material_ui.dart';

class OverlayGestures extends ConsumerWidget {
  final int seriesId;
  final VoidCallback? onCenterTap;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final bool disableGestures;

  const OverlayGestures({
    super.key,
    required this.seriesId,
    this.onCenterTap,
    this.onLeftTap,
    this.onRightTap,
    this.disableGestures = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(overlayGesturesProvider(seriesId: seriesId));

    bool shouldDefer(Offset globalPosition) {
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(
        result,
        globalPosition,
        View.of(context).viewId,
      );

      return result.path.any((entry) {
        final target = entry.target;
        return (target is TextSpan && target.recognizer != null) ||
            target is RenderLinkHitRegion;
      });
    }

    return IgnorePointer(
      ignoring: disableGestures,
      child: Padding(
        padding: .only(
          bottom: MediaQuery.systemGestureInsetsOf(context).bottom,
        ),
        child: Async(
          asyncValue: model,
          data: (data) {
            return Row(
              textDirection: data.readDirection.toTextDirection(),
              children: [
                if (data.navigationGestures)
                  Flexible(
                    flex: 1,
                    child: _OverlayTapDetector(
                      shouldDefer: shouldDefer,
                      onTap: onLeftTap,
                    ),
                  ),
                Flexible(
                  flex: 2,
                  child: _OverlayTapDetector(
                    shouldDefer: shouldDefer,
                    onTap: onCenterTap,
                  ),
                ),
                if (data.navigationGestures)
                  Flexible(
                    flex: 1,
                    child: _OverlayTapDetector(
                      shouldDefer: shouldDefer,
                      onTap: onRightTap,
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _OverlayTapDetector extends StatelessWidget {
  final bool Function(Offset globalPosition) shouldDefer;
  final VoidCallback? onTap;

  const _OverlayTapDetector({
    required this.shouldDefer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final callback = onTap;
    if (callback == null) {
      return const RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: SizedBox.expand(),
      );
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _LinkAwareTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _LinkAwareTapGestureRecognizer
            >(
              () => _LinkAwareTapGestureRecognizer(shouldDefer: shouldDefer),
              (recognizer) => recognizer.onTap = callback,
            ),
      },
      child: const SizedBox.expand(),
    );
  }
}

class _LinkAwareTapGestureRecognizer extends TapGestureRecognizer {
  _LinkAwareTapGestureRecognizer({required this.shouldDefer});

  final bool Function(Offset globalPosition) shouldDefer;

  @override
  void addPointer(PointerDownEvent event) {
    if (shouldDefer(event.position)) return;

    super.addPointer(event);
  }
}
