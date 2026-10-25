import 'dart:convert';

/// Notes of Kavita annotations are Quill documents, written by the web
/// reader's editor: `comment` holds the Delta as JSON and `commentHtml` its
/// semantic HTML. Kover edits them as plain text.
abstract final class QuillNote {
  /// The Delta JSON of the plain [text], `{}` when empty, like the web reader.
  static String delta(String text) {
    if (text.isEmpty) return '{}';

    return jsonEncode({
      'ops': [
        {'insert': '$text\n'},
      ],
    });
  }

  /// The HTML of the plain [text] like Quill's semantic HTML: a paragraph per
  /// line, escaped, with non-breaking spaces.
  static String html(String text) {
    if (text.isEmpty) return '';

    return text
        .split('\n')
        .map(
          (line) => line.isEmpty
              ? '<p><br></p>'
              : '<p>${_escape(line).replaceAll(' ', '&nbsp;')}</p>',
        )
        .join();
  }

  /// The plain text of the Delta JSON [comment], or null when it isn't one.
  static String? text(String? comment) {
    if (comment == null) return null;

    try {
      final document = jsonDecode(comment);
      if (document is! Map) return null;

      final ops = document['ops'];
      if (ops == null) return document.isEmpty ? '' : null;
      if (ops is! List) return null;

      final text = ops
          .map((op) => op is Map && op['insert'] is String ? op['insert'] : '')
          .join();
      // Quill documents always end with a newline.
      return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
    } on FormatException {
      return null;
    }
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
