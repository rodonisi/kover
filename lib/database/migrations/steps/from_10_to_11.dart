import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom10To11(
  AppDatabase db,
  Migrator m,
  Schema11 schema,
) async {
  await db.transaction(() async {
    await m.createTable(schema.smartFilters);
    await m.createTable(schema.smartFilterSeries);
    await m.createTable(schema.smartFilterReadingList);
    await m.createTable(schema.smartFilterPerson);
    await m.createTable(schema.dashboard);
  });
}
