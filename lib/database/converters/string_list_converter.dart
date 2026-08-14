import 'dart:convert';

import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    // Convert the stored JSON string back into a Dart List
    final List<dynamic> decoded = json.decode(fromDb) as List<dynamic>;
    return decoded.map((item) => item.toString()).toList();
  }

  @override
  String toSql(List<String> value) {
    // Convert the Dart List into a JSON string for the DB
    return jsonEncode(value);
  }
}
