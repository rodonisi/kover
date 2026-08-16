import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';

typedef BreakpointBuilderCallback = Widget Function(BuildContext context);

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
