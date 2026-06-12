import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/utils/lifecycle.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity.g.dart';

/// Returns wheter a connection to the server can be established.
@Riverpod(keepAlive: true)
Stream<bool> hasConnection(Ref ref) async* {
  final ping = ref.watch(pingProvider).value ?? false;

  final observer = LifecycleOnResumeObserver(
    onResume: () {
      if (ref.mounted) ref.invalidate(pingProvider);
    },
  );

  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

  final current = await Connectivity().checkConnectivity();
  final hasInterface = !current.contains(ConnectivityResult.none);
  yield hasInterface && ping;

  await for (final results in Connectivity().onConnectivityChanged) {
    final online = !results.contains(ConnectivityResult.none);

    if (online && ref.mounted) ref.invalidate(pingProvider);

    yield online && ping;
  }
}

Duration? _neverRetry(int retryCount, Object error) => null;

@Riverpod(retry: _neverRetry, keepAlive: true)
Future<bool> ping(Ref ref) async {
  final client = ref.watch(restClientProvider);

  final timer = Timer(const Duration(minutes: 5), () {
    ref.invalidateSelf();
  });

  ref.onDispose(timer.cancel);

  try {
    final res = await client.apiAccountRefreshAccountGet();
    return res.isSuccessful;
  } catch (e, stacktrace) {
    log.error('ping error', error: e, stacktrace: stacktrace);
    return false;
  }
}
