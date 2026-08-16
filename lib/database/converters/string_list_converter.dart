import 'dart:convert';

import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final List<dynamic> decoded = json.decode(fromDb) as List<dynamic>;
    return decoded.map((item) => item.toString()).toList();
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}
