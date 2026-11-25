import 'package:freezed_annotation/freezed_annotation.dart';

part 'annotation_draft.freezed.dart';

@freezed
class const AnnotationDraft({
  required final String xPath,
  required final String endingXPath,
  required final String selectedText,
  required final String context,
}) with _$AnnotationDraft;
