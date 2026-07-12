import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';

class OverlayGestures extends ConsumerWidget {
  final int seriesId;
  final VoidCallback? onCenterTap;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final bool disableGestures;
  final Widget? child;

  const OverlayGestures({
    super.key,
    required this.seriesId,
    this.onCenterTap,
    this.onLeftTap,
    this.onRightTap,
    this.disableGestures = false,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationGestures = ref.watch(
      commonReaderSettingsProvider(
        seriesId: seriesId,
      ).select(
        (value) =>
            value.whenOrNull(
              data: (data) => data.navigationGersturesEnabled,
            ) ??
            const CommonReaderSettingsState().navigationGersturesEnabled,
      ),
    );

    return IgnorePointer(
      ignoring: disableGestures,
      child: Row(
        children: [
          if (navigationGestures)
            Flexible(
              flex: 1,
              child: GestureDetector(
                behavior: .translucent,
                onTap: onLeftTap,
              ),
            ),
          Flexible(
            flex: 2,
            child: GestureDetector(behavior: .translucent, onTap: onCenterTap),
          ),
          if (navigationGestures)
            Flexible(
              flex: 1,
              child: GestureDetector(
                behavior: .translucent,
                onTap: onRightTap,
              ),
            ),
        ],
      ),
    );
  }
}
