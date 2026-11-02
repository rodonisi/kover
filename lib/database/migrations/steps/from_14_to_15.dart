import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom14To15(
  AppDatabase db,
  Migrator m,
  Schema15 schema,
) async {
  await db.transaction(() async {
    await m.alterTable(
      TableMigration(
        schema.smartFilterSeries,
        newColumns: [schema.smartFilterSeries.sortOrder],
      ),
    );
    await m.alterTable(
      TableMigration(
        schema.smartFilterReadingList,
        newColumns: [schema.smartFilterReadingList.sortOrder],
      ),
    );
    await m.alterTable(
      TableMigration(
        schema.smartFilterPerson,
        newColumns: [schema.smartFilterPerson.sortOrder],
      ),
    );
  });
}
