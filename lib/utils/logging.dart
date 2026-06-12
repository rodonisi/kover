import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'logging.freezed.dart';

enum LogLevel {
  debug(1),
  info(2),
  warning(3),
  error(4),
  fatal(5);

  final int severity;
  const LogLevel(this.severity);

  bool operator >(LogLevel other) => severity > other.severity;
  bool operator <(LogLevel other) => severity < other.severity;
}

@freezed
sealed class LogAttribute with _$LogAttribute {
  const factory LogAttribute.string(String value) = StringLogAttribute;
  const factory LogAttribute.int(int value) = IntLogAttribute;
  const factory LogAttribute.double(double value) = DoubleLogAttribute;
  const factory LogAttribute.bool(bool value) = BoolLogAttribute;
}

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

  KoverLogger({this.level = .debug});

  void debug(
    dynamic message, {
    Map<String, LogAttribute> attributes = const {},
  }) {
    if (level > .debug) return;

    _logMessage(.debug, message);
    Sentry.logger.debug(
      message.toString(),
      attributes: _mapSentryAttributes(attributes),
    );
  }

  void info(
    dynamic message, {
    Map<String, LogAttribute> attributes = const {},
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
    Map<String, LogAttribute> attributes = const {},
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
    Map<String, LogAttribute> attributes = const {},
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
    Map<String, LogAttribute> attributes = const {},
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
    Map<String, LogAttribute> attributes = const {},
  }) {
    _logLocal(
      level,
      message,
      error: error,
      stacktrace: stacktrace,
      attributes: attributes,
    );
    _sendBreadcrumb(level, message, attributes: attributes);
  }

  void _logLocal(
    LogLevel level,
    dynamic message, {
    Object? error,
    StackTrace? stacktrace,
    Map<String, LogAttribute> attributes = const {},
  }) {
    final Level mappedLevel = switch (level) {
      .debug => .debug,
      .info => .info,
      .warning => .warning,
      .error => .error,
      .fatal => .fatal,
    };
    final attributeString = attributes.entries
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
    Map<String, LogAttribute> attributes = const {},
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
    Map<String, LogAttribute> attributes,
  ) {
    return attributes.map(
      (key, value) => MapEntry(
        key,
        value.when(
          string: (value) => SentryAttribute.string(value),
          int: (value) => SentryAttribute.int(value),
          double: (value) => SentryAttribute.double(value),
          bool: (value) => SentryAttribute.bool(value),
        ),
      ),
    );
  }
}

final log = KoverLogger(level: kDebugMode ? LogLevel.debug : LogLevel.info);
