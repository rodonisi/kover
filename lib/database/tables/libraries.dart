import 'package:drift/drift.dart';
import 'package:kover/models/enums/library_type.dart';

class Libraries extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<LibraryType>()();
  BoolColumn get includeInDashboard =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeInRecommended =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeInSearch =>
      boolean().withDefault(const Constant(true))();
  TextColumn get defaultLanguage => text().nullable()();

  DateTimeColumn get lastScanned => dateTime().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
