import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom7To8(AppDatabase db, Migrator m, Schema8 schema) async {
  await db.transaction(() async {
    await m.createTable(schema.onDeckRemoval);
  });
}
