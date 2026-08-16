import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/utils/layout_constants.dart';

typedef BreakpointBuilderCallback = Widget Function(BuildContext context);
typedef SliverBreakpointBuilderCallback = List<Widget> Function(
  BuildContext context,
);

/// A widget that builds different layouts based on the current [Breakpoint]
/// based on the viewport size.
class BreakpointBuilder extends ConsumerWidget {
  final BreakpointBuilderCallback compactBuilder;
  final BreakpointBuilderCallback? mediumBuilder;
  final BreakpointBuilderCallback? expandedBuilder;
  final BreakpointBuilderCallback? largeBuilder;
  final BreakpointBuilderCallback? largestBuilder;

  const new({
    super.key,
    required this.compactBuilder,
    this.mediumBuilder,
    this.expandedBuilder,
    this.largeBuilder,
    this.largestBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoint = ref.watch(breakpointsProvider);

    if (breakpoint >= .largest && largestBuilder != null) {
      return largestBuilder!(context);
    }

    if (breakpoint >= .large && largeBuilder != null) {
      return largeBuilder!(context);
    }

    if (breakpoint >= .expanded && expandedBuilder != null) {
      return expandedBuilder!(context);
    }

    if (breakpoint >= .medium && mediumBuilder != null) {
      return mediumBuilder!(context);
    }

    return compactBuilder(context);
  }
}

class SliverBreakpointBuilder extends ConsumerWidget {
  final SliverBreakpointBuilderCallback compactBuilder;
  final SliverBreakpointBuilderCallback? mediumBuilder;
  final SliverBreakpointBuilderCallback? expandedBuilder;
  final SliverBreakpointBuilderCallback? largeBuilder;
  final SliverBreakpointBuilderCallback? largestBuilder;

  const SliverBreakpointBuilder({
    super.key,
    required this.compactBuilder,
    this.mediumBuilder,
    this.expandedBuilder,
    this.largeBuilder,
    this.largestBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoint = ref.watch(breakpointsProvider);
    final builder = _select(breakpoint);
    return SliverMainAxisGroup(slivers: builder(context));
  }

  SliverBreakpointBuilderCallback _select(Breakpoint breakpoint) {
    if (breakpoint >= .largest && largestBuilder != null) {
      return largestBuilder!;
    }

    if (breakpoint >= .large && largeBuilder != null) {
      return largeBuilder!;
    }

    if (breakpoint >= .expanded && expandedBuilder != null) {
      return expandedBuilder!;
    }

    if (breakpoint >= .medium && mediumBuilder != null) {
      return mediumBuilder!;
    }

    return compactBuilder;
  }
}

class SliverAdaptivePadding extends StatelessWidget {
  final Widget sliver;

  const new({super.key, required this.sliver});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final side =
            (constraints.crossAxisExtent - LayoutBreakpoints.large).clamp(
              0,
              double.infinity,
            ) /
            2;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: sliver,
        );
      },
    );
  }
}
