import 'package:drift/drift.dart';
import 'package:kover/models/enums/font_provider.dart';

class ServerFonts extends Table {
  IntColumn get id => integer()();
  TextColumn get family => text()();
  TextColumn get name => text().nullable()();
  TextColumn get provider => textEnum<FontProvider>()();
  TextColumn get fileName => text().nullable()();
  TextColumn get style => text().nullable()();
  TextColumn get weight => text().nullable()();
  BlobColumn get data => blob()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
