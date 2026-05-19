import 'package:drift/drift.dart';

class ServerSettings extends Table {
  TextColumn get key => text()();

  TextColumn get installVersion => text().nullable()();
  IntColumn get onDeckProgressDays => integer()();
  IntColumn get onDeckUpdateDays => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {key};
}
