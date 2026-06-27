import 'package:drift/drift.dart';
import 'package:kover/models/enums/sidenav_stream_type.dart';

class Sidenav extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get order => integer()();
  BoolColumn get visible => boolean()();
  TextColumn get streamType => textEnum<SidenavStreamType>()();
  IntColumn get libraryId => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
