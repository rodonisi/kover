import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      debugPrint(line);
    }

    final fullMessage = event.lines.join('\n');

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: fullMessage,
        level: switch (event.level) {
          .info => .info,
          .warning => .warning,
          .error => .error,
          .fatal => .fatal,
          _ => .debug,
        },
        category: 'app.logger',
      ),
    );

    switch (event.level) {
      case .info:
        Sentry.logger.info(
          event.origin.message,
          attributes: {
            'full_message': SentryAttribute.string(fullMessage),
          },
        );
        break;
      case .warning:
        Sentry.logger.warn(
          event.origin.message,
          attributes: {
            'full_message': SentryAttribute.string(fullMessage),
          },
        );
        break;
      case .error:
      case .fatal:
        Sentry.captureException(
          fullMessage,
          stackTrace: event.origin.stackTrace,
        );
        Sentry.logger.error(
          event.origin.message,
          attributes: {
            'full_message': SentryAttribute.string(fullMessage),
          },
        );
        break;
      default:
        Sentry.logger.debug(
          event.origin.message,
          attributes: {
            'full_message': SentryAttribute.string(fullMessage),
          },
        );
        break;
    }
  }
}

final log = Logger(
  level: kDebugMode ? .all : .info,
  output: SentryLogOutput(),
);
