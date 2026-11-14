import 'dart:convert';

import 'package:drift/drift.dart';

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    final List<dynamic> decoded = json.decode(fromDb) as List<dynamic>;
    return decoded.map((item) => (item as num).toInt()).toList();
  }

  @override
  String toSql(List<int> value) {
    return jsonEncode(value);
  }
}
