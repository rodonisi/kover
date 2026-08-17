import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';

class BreakpointsWatcher extends ConsumerWidget {
  final Widget child;

  const BreakpointsWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final usableWidth =
              constraints.maxWidth - MediaQuery.paddingOf(context).horizontal;
          ref.read(breakpointsProvider.notifier).update(usableWidth);
        });

        return child;
      },
    );
  }
}
