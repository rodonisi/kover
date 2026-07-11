import 'package:flutter/material.dart';

class OverlayGestures extends StatelessWidget {
  final VoidCallback? onCenterTap;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final bool disableGestures;
  final Widget? child;

  const OverlayGestures({
    super.key,
    this.onCenterTap,
    this.onLeftTap,
    this.onRightTap,
    this.disableGestures = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: disableGestures,
      child: Row(
        children: [
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
          Flexible(
            flex: 1,
            child: GestureDetector(
              behavior: .translucent,
              onTap: () => onRightTap,
            ),
          ),
        ],
      ),
    );
  }
}
