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

class Async2<T1, T2> extends StatelessWidget {
  final AsyncValue<T1> asyncValue1;
  final AsyncValue<T2> asyncValue2;
  final Widget Function(T1, T2) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  const Async2({
    super.key,
    required this.asyncValue1,
    required this.asyncValue2,
    required this.data,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (asyncValue1.isLoading || asyncValue2.isLoading) {
      return loading?.call() ??
          const Center(child: CircularProgressIndicator());
    } else if (asyncValue1.hasError) {
      return error?.call(asyncValue1.error!, asyncValue1.stackTrace!) ??
          _Error(
            error: asyncValue1.error!,
            stacktrace: asyncValue1.stackTrace!,
          );
    } else if (asyncValue2.hasError) {
      return error?.call(asyncValue2.error!, asyncValue2.stackTrace!) ??
          _Error(
            error: asyncValue2.error!,
            stacktrace: asyncValue2.stackTrace!,
          );
    }

    return data(asyncValue1.value as T1, asyncValue2.value as T2);
  }
}

class Async3<T1, T2, T3> extends StatelessWidget {
  final AsyncValue<T1> asyncValue1;
  final AsyncValue<T2> asyncValue2;
  final AsyncValue<T3> asyncValue3;
  final Widget Function(T1, T2, T3) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  const Async3({
    super.key,
    required this.asyncValue1,
    required this.asyncValue2,
    required this.asyncValue3,
    required this.data,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (asyncValue1.isLoading ||
        asyncValue2.isLoading ||
        asyncValue3.isLoading) {
      return loading?.call() ??
          const Center(child: CircularProgressIndicator());
    } else if (asyncValue1.hasError) {
      return error?.call(asyncValue1.error!, asyncValue1.stackTrace!) ??
          _Error(
            error: asyncValue1.error!,
            stacktrace: asyncValue1.stackTrace!,
          );
    } else if (asyncValue2.hasError) {
      return error?.call(asyncValue2.error!, asyncValue2.stackTrace!) ??
          _Error(
            error: asyncValue2.error!,
            stacktrace: asyncValue2.stackTrace!,
          );
    } else if (asyncValue3.hasError) {
      return error?.call(asyncValue3.error!, asyncValue3.stackTrace!) ??
          _Error(
            error: asyncValue3.error!,
            stacktrace: asyncValue3.stackTrace!,
          );
    }

    return data(
      asyncValue1.value as T1,
      asyncValue2.value as T2,
      asyncValue3.value as T3,
    );
  }
}

class Async4<T1, T2, T3, T4> extends StatelessWidget {
  final AsyncValue<T1> asyncValue1;
  final AsyncValue<T2> asyncValue2;
  final AsyncValue<T3> asyncValue3;
  final AsyncValue<T4> asyncValue4;
  final Widget Function(T1, T2, T3, T4) data;
  final Widget Function()? loading;
  final Widget Function(Object, StackTrace)? error;

  const Async4({
    super.key,
    required this.asyncValue1,
    required this.asyncValue2,
    required this.asyncValue3,
    required this.asyncValue4,
    required this.data,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (asyncValue1.isLoading ||
        asyncValue2.isLoading ||
        asyncValue3.isLoading ||
        asyncValue4.isLoading) {
      return loading?.call() ??
          const Center(child: CircularProgressIndicator());
    } else if (asyncValue1.hasError) {
      return error?.call(asyncValue1.error!, asyncValue1.stackTrace!) ??
          _Error(
            error: asyncValue1.error!,
            stacktrace: asyncValue1.stackTrace!,
          );
    } else if (asyncValue2.hasError) {
      return error?.call(asyncValue2.error!, asyncValue2.stackTrace!) ??
          _Error(
            error: asyncValue2.error!,
            stacktrace: asyncValue2.stackTrace!,
          );
    } else if (asyncValue3.hasError) {
      return error?.call(asyncValue3.error!, asyncValue3.stackTrace!) ??
          _Error(
            error: asyncValue3.error!,
            stacktrace: asyncValue3.stackTrace!,
          );
    } else if (asyncValue4.hasError) {
      return error?.call(asyncValue4.error!, asyncValue4.stackTrace!) ??
          _Error(
            error: asyncValue4.error!,
            stacktrace: asyncValue4.stackTrace!,
          );
    }

    return data(
      asyncValue1.value as T1,
      asyncValue2.value as T2,
      asyncValue3.value as T3,
      asyncValue4.value as T4,
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
    log.error('provider errored', error: error, stacktrace: stacktrace);
    return Center(
      child: Icon(
        LucideIcons.circleX,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
