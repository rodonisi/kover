import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/logging.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class Async<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  const Async({
    super.key,
    required this.asyncValue,
    required this.data,
    this.loading,
    this.error,
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
    );
  }
}

class AsyncSliver<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  const AsyncSliver({
    super.key,
    required this.asyncValue,
    required this.data,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
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
    log.e(
      'Provider errored',
      error: error,
      stackTrace: stacktrace,
    );
    return Center(
      child: Icon(
        LucideIcons.circleX,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
