import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom11To12(
  AppDatabase db,
  Migrator m,
  Schema12 schema,
) async {
  await db.transaction(() async {
    await m.createTable(schema.serverFonts);
  });
}
