import 'package:drift/drift.dart';
import 'package:kover/models/enums/dashboard_stream_type.dart';

class Dashboard extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get order => integer()();
  BoolColumn get visible => boolean()();
  TextColumn get streamType => textEnum<DashboardSectionType>()();
  IntColumn get smartFilterId => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
