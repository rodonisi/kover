import 'package:freezed_annotation/freezed_annotation.dart';

part 'font_face.freezed.dart';
part 'font_face.g.dart';

@freezed
sealed class FontFace with _$FontFace {
  const factory FontFace({
    required String family,
    int? weight,
    required String url,
  }) = _FontFace;

  factory FontFace.fromJson(Map<String, dynamic> json) =>
      _$FontFaceFromJson(json);
}
