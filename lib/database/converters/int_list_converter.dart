import 'dart:convert';

import 'package:drift/drift.dart';

class const IntListConverter() extends TypeConverter<List<int>, String> {
  @override
  List<int> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);

    if (decoded is! List) {
      throw FormatException('Expected a JSON array', fromDb);
    }

    return decoded
        .map((item) {
          if (item is! num) {
            throw FormatException('Expected an array of numbers', fromDb);
          }
          return item.toInt();
        })
        .toList(growable: false);
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);
}
