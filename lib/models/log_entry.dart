import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entry.freezed.dart';
part 'log_entry.g.dart';

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
sealed class LogEntry with _$LogEntry {
  const LogEntry._();

  const factory LogEntry({
    required DateTime timestamp,
    required LogLevel level,
    required String message,
    required Map<String, String> attributes,
    @Default(null) String? error,
  }) = _LogEntry;

  factory LogEntry.fromJson(Map<String, dynamic> json) =>
      _$LogEntryFromJson(json);
}
