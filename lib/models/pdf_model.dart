import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/utils/converters/uint8list_converter.dart';

part 'pdf_model.freezed.dart';
part 'pdf_model.g.dart';

@freezed
sealed class PdfModel with _$PdfModel {
  const PdfModel._();

  const factory PdfModel.data({
    @Uint8ListConverter() required Uint8List data,
  }) = PdfDataModel;

  const factory PdfModel.file({
    required String path,
  }) = PdfFileModel;

  factory PdfModel.fromJson(Map<String, Object?> json) =>
      _$PdfModelFromJson(json);
}
