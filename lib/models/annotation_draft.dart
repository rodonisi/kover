import 'package:freezed_annotation/freezed_annotation.dart';

part 'annotation_draft.freezed.dart';

/// An unsaved annotation captured from a text selection.
@freezed
class const AnnotationDraft({
  /// The XPath of the element where the selection starts.
  required final String xPath,

  /// The XPath of the element where the selection ends.
  required final String endingXPath,
  required final String selectedText,

  /// The text of the element where the selection ends.
  required final String context,
}) with _$AnnotationDraft;
