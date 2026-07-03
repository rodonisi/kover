import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/utils/converters/uint8list_converter.dart';

part 'image_model.freezed.dart';
part 'image_model.g.dart';

@freezed
sealed class ImageModel with _$ImageModel {
  const ImageModel._();

  const factory ImageModel({
    @Uint8ListConverter() required Uint8List data,
  }) = _ImageModel;

  factory ImageModel.fromJson(Map<String, Object?> json) =>
      _$ImageModelFromJson(json);

  /// Fast O(1) equality that avoids byte-by-byte comparison of large image
  /// data. Samples length + a few bytes to detect changes without blocking
  /// the main thread
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! ImageModel) return false;

    final o = other.data;

    if (data.length != o.length) return false;

    if (data.isEmpty) return true;

    return data.first == o.first &&
        data.last == o.last &&
        data[data.length >> 1] == o[data.length >> 1];
  }

  @override
  int get hashCode => Object.hash(
    data.length,
    data.isEmpty ? 0 : data.first,
    data.isEmpty ? 0 : data.last,
    data[data.length >> 1],
  );
}
