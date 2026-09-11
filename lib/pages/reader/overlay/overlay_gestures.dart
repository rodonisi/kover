import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/mapping/enums/read_direction.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures_provider.dart';
import 'package:kover/widgets/util/async_value.dart';
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

    return IgnorePointer(
      ignoring: disableGestures,
      child: Async(
        asyncValue: model,
        data: (data) {
          return Row(
            textDirection: data.readDirection.toTextDirection(),
            children: [
              if (data.navigationGestures)
                Flexible(
                  flex: 1,
                  child: GestureDetector(
                    behavior: .translucent,
                    onTap: onLeftTap,
                  ),
                ),
              Flexible(
                flex: 2,
                child: GestureDetector(
                  behavior: .translucent,
                  onTap: onCenterTap,
                ),
              ),
              if (data.navigationGestures)
                Flexible(
                  flex: 1,
                  child: GestureDetector(
                    behavior: .translucent,
                    onTap: onRightTap,
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
      ),
    );
  }
}
