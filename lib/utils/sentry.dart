import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> initializeSentry({
  required FutureOr<void> Function() appRunner,
}) async {
  await SentryFlutter.init(
    sentryOptionsConfiguration,
    appRunner: appRunner,
  );
}

FutureOr<void> sentryOptionsConfiguration(SentryFlutterOptions options) {
  options.dsn = _sentryDsn;
  options.sendDefaultPii = false;
  options.enableLogs = true;
  options.enableTombstone = true;
  options.tracesSampleRate = 1.0;
  // ignore: experimental_member_use
  options.profilesSampleRate = 1.0;
  options.replay.sessionSampleRate = 0.1;
  options.replay.onErrorSampleRate = 1.0;
  options.beforeSend = (event, hint) {
    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final exception in exceptions) {
        final value = exception.value;
        if (value != null) {
          // scrub URLs from exception messages
          exception.value = value.replaceAll(
            RegExp(r'https?://[^\s,]+'),
            '[scrubbed]',
          );
        }
      }
    }
    return event;
  };
}
