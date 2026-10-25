import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/api/openapi.swagger.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
sealed class UserModel with _$UserModel {
  const factory UserModel({
    required int id,
    required String username,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromUserDto(UserDto dto) {
    return UserModel(
      // Kavita's plugin authentication leaves the id out (0); the token it
      // returns has it.
      id: switch (dto.id) {
        final id? when id != 0 => id,
        _ => _idFromToken(dto.token) ?? 0,
      },
      username: dto.username!,
    );
  }

  /// The user id in the `nameid` claim of the JWT [token].
  static int? _idFromToken(String? token) {
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;

    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return claims is Map ? int.tryParse('${claims['nameid']}') : null;
    } on FormatException {
      return null;
    }
  }
}
