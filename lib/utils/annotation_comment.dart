import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

typedef EncodedAnnotationComment = ({
  String? comment,
  String? commentHtml,
  String? commentPlainText,
});

/// Converts annotation comments between Quill documents and Kavita's formats.
///
/// Kavita stores a comment as a Quill Delta JSON string together with its HTML
/// and plain-text renderings.
abstract final class AnnotationComment {
  static const EncodedAnnotationComment empty = (
    comment: null,
    commentHtml: null,
    commentPlainText: null,
  );

  /// Decodes stored Kavita comment fields into a Quill [quill.Document].
  static quill.Document toDocument({
    String? comment,
    String? commentPlainText,
  }) {
    final raw = comment?.trim();
    if (raw != null && raw.isNotEmpty) {
      final decoded = _tryDecodeJson(raw);
      if (decoded is Map) {
        final ops = decoded['ops'];
        if (ops is List) {
          final document = _tryDocumentFromOps(ops);
          if (document != null) return document;
        } else {
          // Kavita stores an untouched note as "{}".
          return quill.Document();
        }
      } else if (decoded == null) {
        return quill.Document()..insert(0, raw);
      }
    }

    final fallback = commentPlainText?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return quill.Document()..insert(0, fallback);
    }

    return quill.Document();
  }

  /// Encodes a Quill [document] into Kavita's Delta, HTML, and plain-text fields.
  static EncodedAnnotationComment fromDocument(quill.Document document) {
    final ops = document.toDelta().toJson();
    final plainText = document.toPlainText().trim();
    final hasEmbed = ops.any((op) => op['insert'] is! String);
    if (plainText.isEmpty && !hasEmbed) return empty;

    final html = QuillDeltaToHtmlConverter(
      ops,
      ConverterOptions(multiLineParagraph: false),
    ).convert();

    return (
      comment: jsonEncode({'ops': ops}),
      commentHtml: html.trim().isEmpty ? null : html,
      commentPlainText: plainText.isEmpty ? null : plainText,
    );
  }

  /// Decodes a stored [comment] into plain text.
  ///
  /// Used as a fallback when `commentHtml` is absent. Returns `null` when the
  /// comment is empty, or when it is a Quill Delta with non-text embeds.
  static String? toPlainText(String? comment) {
    final raw = comment?.trim();
    if (raw == null || raw.isEmpty) return null;

    final json = _tryDecodeJson(raw);
    if (json == null) return raw;
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

  static Object? _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static quill.Document? _tryDocumentFromOps(List<dynamic> ops) {
    if (ops.isEmpty) return quill.Document();

    final normalized = List<dynamic>.from(ops);
    final last = normalized.last;
    final lastInsert = last is Map ? last['insert'] : null;
    if (lastInsert is! String || !lastInsert.endsWith('\n')) {
      normalized.add({'insert': '\n'});
    }

    try {
      return quill.Document.fromJson(normalized);
    } catch (_) {
      return null;
    }
  }
}
