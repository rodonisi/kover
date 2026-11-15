import 'package:drift/drift.dart';

class HighlightSlots extends Table {
  IntColumn get slotNumber => integer()();
  IntColumn get red => integer().nullable()();
  IntColumn get green => integer().nullable()();
  IntColumn get blue => integer().nullable()();
  RealColumn get alpha => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {slotNumber};
}
