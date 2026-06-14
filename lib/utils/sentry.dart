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
    _scrubExceptions(event.exceptions ?? []);
    _scrubMessage(event.message);
    return event;
  };
}

void _scrubExceptions(List<SentryException> exceptions) {
  for (final exception in exceptions) {
    exception.scrubUrls();
  }
}

void _scrubMessage(SentryMessage? message) {
  message?.scrubUrls();
}

String _scrubLooseUrls(String input) {
  final looseUrlRegex = RegExp(
    r'(?:https?:\/\/|www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{2,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );
  return input.replaceAll(looseUrlRegex, '[scrubbed]');
}

extension on SentryException {
  void scrubUrls() {
    value = _scrubLooseUrls(value ?? '');
  }
}

extension on SentryMessage {
  void scrubUrls() {
    formatted = _scrubLooseUrls(formatted);
  }
}
