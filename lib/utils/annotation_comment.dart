import 'dart:convert';

/// Converts annotation comments between plain text and Kavita's formats.
///
/// Kavita stores a comment as a Quill Delta JSON string together with its HTML
/// rendering. Kover only edits plain text.
abstract final class AnnotationComment {
  /// Encodes [text] as a Quill Delta, or `null` when it is blank.
  static String? toDelta(String? text) {
    final value = _clean(text);
    if (value == null) return null;

    return jsonEncode({
      'ops': [
        {'insert': '$value\n'},
      ],
    });
  }

  /// Encodes [text] as one HTML paragraph per line, or `null` when it is
  /// blank.
  static String? toHtml(String? text) {
    final value = _clean(text);
    if (value == null) return null;

    return value
        .split('\n')
        .map((line) => '<p>${_htmlEscape.convert(line)}</p>')
        .join();
  }

  /// Decodes a stored [comment] into plain text.
  ///
  /// Returns `null` when the comment is empty, or when it is a Quill Delta
  /// with content other than text, such as images. Comments that are not a
  /// Quill Delta are returned unchanged.
  static String? toPlainText(String? comment) {
    final raw = comment?.trim();
    if (raw == null || raw.isEmpty) return null;

    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return raw;
    }
    if (json is! Map) return raw;

    // Kavita stores an untouched note as "{}".
    final ops = json['ops'];
    if (ops is! List) return null;

    final text = StringBuffer();
    for (final op in ops) {
      final insert = op is Map ? op['insert'] : null;
      if (insert is! String) return null;
      text.write(insert);
    }

    final value = text.toString().trim();
    return value.isEmpty ? null : value;
  }

  static String? _clean(String? text) {
    final value = text?.replaceAll('\r\n', '\n').trim();
    return value == null || value.isEmpty ? null : value;
  }

  static const _htmlEscape = HtmlEscape(HtmlEscapeMode.element);
}
