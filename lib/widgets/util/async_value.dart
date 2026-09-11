import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/logging.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Helper widget to display an [AsyncValue] in the UI.
/// If no loading builder is probided, a [CircularProgressIndicator] is shown.
/// If no error builder is provided, an error icon is shown and the error is logged.
class Async<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;
  final bool skipLoadingOnReload;

  const new({
    super.key,
    required this.asyncValue,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnReload = true,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: data,
      loading:
          loading ?? () => const Center(child: CircularProgressIndicator()),
      error:
          error ??
          (error, stack) => _Error(
            error: error,
            stacktrace: stack,
          ),
      skipLoadingOnReload: skipLoadingOnReload,
    );
  }
}

/// Helper widget to display an [AsyncValue] as a sliver in the UI.
/// If no loading builder is probided, a [CircularProgressIndicator] is shown.
/// If no error builder is provided, an error icon is shown and the error is logged.
class AsyncSliver<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;
  final bool skipLoadingOnReload;

  const new({
    super.key,
    required this.asyncValue,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnReload = true,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      skipLoadingOnReload: skipLoadingOnReload,
      data: data,
      loading:
          loading ??
          () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          error ??
          (error, stack) {
            return SliverToBoxAdapter(
              child: _Error(
                error: error,
                stacktrace: stack,
              ),
            );
          },
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;
  final StackTrace stacktrace;
  const _Error({required this.error, required this.stacktrace});

  @override
  Widget build(BuildContext context) {
    log.error('provider errored', error: error, stacktrace: stacktrace);
    return Center(
      child: Icon(
        LucideIcons.circleX,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
