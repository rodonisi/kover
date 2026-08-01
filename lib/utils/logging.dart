import 'package:flutter/foundation.dart';
import 'package:kover/models/log_entry.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef Sink = void Function(LogEntry entry);

class KoverLogger {
  final localLogger = Logger(
    printer: PrettyPrinter(
      stackTraceBeginIndex: 3,
      methodCount: 4,
      errorMethodCount: 12,
      colors: true,
      printEmojis: true,
    ),
  );
  final LogLevel level;
  Sink? sink;

  KoverLogger({this.level = .debug});

  void debug(
    dynamic message, {
    Map<String, dynamic> attributes = const {},
  }) {
    if (level > .debug) return;

    _logMessage(.debug, message, attributes: attributes);
    Sentry.logger.debug(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void info(
    dynamic message, {
    Map<String, dynamic> attributes = const {},
  }) {
    if (level > .info) return;

    _logMessage(.info, message, attributes: attributes);
    Sentry.logger.info(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void warning(
    dynamic message, {
    Map<String, dynamic> attributes = const {},
  }) {
    if (level > .warning) return;

    _logMessage(.warning, message, attributes: attributes);
    Sentry.logger.warn(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void error(
    dynamic message, {
    Object? error,
    StackTrace? stacktrace,
    Map<String, dynamic> attributes = const {},
  }) {
    if (level > .error) return;

    _logMessage(
      .error,
      message,
      error: error,
      stacktrace: stacktrace,
      attributes: attributes,
    );
    Sentry.captureException(
      error,
      stackTrace: stacktrace ?? StackTrace.current,
      message: SentryMessage(message.toString()),
    );
    Sentry.logger.error(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void fatal(
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic> attributes = const {},
  }) {
    if (level > .fatal) return;

    _logMessage(
      .fatal,
      message,
      error: error,
      stacktrace: stackTrace,
      attributes: attributes,
    );
    Sentry.captureException(
      error,
      stackTrace: stackTrace ?? StackTrace.current,
      message: SentryMessage(message.toString()),
    );
    Sentry.logger.fatal(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void _logMessage(
    LogLevel level,
    dynamic message, {
    Object? error,
    StackTrace? stacktrace,
    Map<String, dynamic> attributes = const {},
  }) {
    _logLocal(
      level,
      message,
      error: error,
      stacktrace: stacktrace,
      attributes: attributes,
    );

    sink?.call(
      LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message.toString(),
        attributes: attributes.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        error: error.toString(),
      ),
    );

    _sendBreadcrumb(level, message, attributes: attributes);
  }

  void _logLocal(
    LogLevel level,
    dynamic message, {
    Object? error,
    StackTrace? stacktrace,
    Map<String, dynamic> attributes = const {},
  }) {
    final Level mappedLevel = switch (level) {
      .debug => .debug,
      .info => .info,
      .warning => .warning,
      .error => .error,
      .fatal => .fatal,
    };
    final sentryAttributes = _mapSentryAttributes(attributes);
    final attributeString = sentryAttributes.entries
        .map((e) => '${e.key}: ${e.value.value}')
        .join('\n');
    final fullMessage = '$message\n$attributeString'.trim();
    localLogger.log(
      mappedLevel,
      fullMessage,
      error: error,
      stackTrace: stacktrace,
    );
  }

  void _sendBreadcrumb(
    LogLevel level,
    dynamic message, {
    Map<String, dynamic> attributes = const {},
  }) {
    final SentryLevel sentryLevel = switch (level) {
      .debug => .debug,
      .info => .info,
      .warning => .warning,
      .error => .error,
      .fatal => .fatal,
    };
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message.toString(),
        level: sentryLevel,
        category: 'app.logger',
        data: attributes.map((key, value) => MapEntry(key, value)),
      ),
    );
  }

  static Map<String, SentryAttribute> _mapSentryAttributes(
    Map<String, dynamic> attributes,
  ) {
    return attributes.map(
      (key, value) {
        final SentryAttribute v = switch (value) {
          String s => .string(s),
          int i => .int(i),
          double d => .double(d),
          bool b => .bool(b),
          Iterable<String> l => .stringArray(l.toList()),
          Iterable<int> l => .intArray(l.toList()),
          Iterable<double> l => .doubleArray(l.toList()),
          Iterable<bool> l => .boolArray(l.toList()),
          Iterable l => .stringArray(
            l.map((e) => e.toString()).toList(),
          ),
          _ => .string(value.toString()),
        };

        return MapEntry(key, v);
      },
    );
  }
}

final log = KoverLogger(level: kDebugMode ? LogLevel.debug : LogLevel.info);
