import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

typedef EncodedAnnotationComment = ({String comment, String? commentHtml});

/// Converts annotation comments between Quill documents and Kavita's formats.
///
/// Kavita stores a comment as a Quill Delta JSON string together with its HTML
/// rendering.
abstract final class AnnotationComment {
  static const EncodedAnnotationComment empty = (
    comment: '{}',
    commentHtml: null,
  );

  /// Decodes a stored Kavita comment Delta into a Quill [quill.Document].
  static quill.Document toDocument(String comment) {
    final decoded = jsonDecode(comment) as Map<String, dynamic>;
    final ops = decoded['ops'];
    if (ops is! List || ops.isEmpty) return quill.Document();

    return quill.Document.fromJson(ops);
  }

  /// Encodes a Quill [document] into Kavita's Delta and HTML fields.
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
    );
  }
}
