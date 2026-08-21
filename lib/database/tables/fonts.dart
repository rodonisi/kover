import 'package:drift/drift.dart';

/// Cached epub font files, extracted from book pages and deduplicated by
/// their original [url]. [weight] distinguishes the individual faces of
/// multi-weight families; [name] is reserved for user/server-provided fonts.
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
