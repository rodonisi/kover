import 'package:drift/drift.dart';

class Fonts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get family => text()();
  TextColumn get name => text().nullable()();
  IntColumn get weight => integer().nullable()();
  TextColumn get url => text()();
  BlobColumn get data => blob()();
  TextColumn get mimeType => text().nullable()();

  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSync => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {url},
  ];
}
