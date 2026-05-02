import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/measured_widget.dart';

class AdaptiveSliverAppBar extends HookConsumerWidget {
  final PreferredSizeWidget? bottom;
  final Widget title;
  final Widget? background;
  final List<Widget>? actions;
  final Widget child;

  const AdaptiveSliverAppBar({
    super.key,
    required this.title,
    this.bottom,
    this.background,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    final isCollapsed = useState(false);
    final infoHeight = useState(500.0);

    final minFlexibleHeight = useMemoized(
      () => kToolbarHeight + topPadding + (bottom?.preferredSize.height ?? 0.0),
      [topPadding, bottom],
    );
    final expandedHeight = useMemoized(
      () => infoHeight.value + (bottom?.preferredSize.height ?? 0.0),
      [infoHeight.value, bottom],
    );

    return SliverAppBar(
      title: isCollapsed.value
          ? title.animate(target: isCollapsed.value ? 1 : 0).fade()
          : null,
      pinned: true,
      expandedHeight: expandedHeight,
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.smallPadding,
      ),
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final value =
              (constraints.maxHeight - minFlexibleHeight) / infoHeight.value;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            isCollapsed.value = constraints.maxHeight <= minFlexibleHeight;
          });

          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (background != null)
                    Positioned.fill(
                      child:
                          background ??
                          Container(color: Theme.of(context).primaryColor),
                    ),
                  SafeArea(
                    child: MeasuredWidget(
                      onSizeMeasured: (size) {
                        infoHeight.value = size.height;
                      },
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottom: bottom,
    );
  }
}
