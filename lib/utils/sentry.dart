import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn =
    'https://b5a6b68eea23284eb215f1661c8661e2@o4511480670060544.ingest.de.sentry.io/4511480676679760';

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
}
