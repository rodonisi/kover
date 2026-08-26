import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/utils/layout_constants.dart';

class AdaptiveSliverGrid extends ConsumerWidget {
  final int itemCount;
  final int? rowCount;
  final NullableIndexedWidgetBuilder builder;
  final void Function(int crossAxisCount)? onCrossAxisCountChanged;

  const AdaptiveSliverGrid({
    super.key,
    required this.builder,
    required this.itemCount,
    this.rowCount,
    this.onCrossAxisCountChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HookBuilder(
      builder: (context) {
        final breakpoint = ref.watch(breakpointsProvider);

        final crossAxisCount = switch (breakpoint) {
          Breakpoint.largest => 10,
          Breakpoint.large => 8,
          Breakpoint.expanded => 6,
          Breakpoint.medium => 4,
          Breakpoint.compact => 3,
        };

        useEffect(() {
          onCrossAxisCountChanged?.call(crossAxisCount);
          return null;
        }, [crossAxisCount]);

        final items = rowCount != null
            ? (rowCount! * crossAxisCount).clamp(0, itemCount)
            : itemCount;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: LayoutConstants.chapterCardAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            builder,
            childCount: items,
          ),
        );
      },
    );
  }
}
