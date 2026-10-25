import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/models/user_model.dart';

void main() {
  String token(Map<String, Object> claims) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'HS512'})}.${part(claims)}.signature';
  }

  group('fromUserDto', () {
    test('takes the id of the user', () {
      final user = UserModel.fromUserDto(
        const UserDto(id: 3, username: 'reader'),
      );

      expect(user, const UserModel(id: 3, username: 'reader'));
    });

    test('reads the id from the token when Kavita leaves it out', () {
      final user = UserModel.fromUserDto(
        UserDto(
          id: 0,
          username: 'reader',
          token: token({'name': 'reader', 'nameid': '2'}),
        ),
      );

      expect(user.id, 2);
    });

    test('has id 0 without a readable token', () {
      expect(
        UserModel.fromUserDto(
          const UserDto(username: 'reader', token: 'not a token'),
        ).id,
        0,
      );
    });
  });
}
