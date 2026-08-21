import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom5To6(AppDatabase db, Migrator m, Schema6 schema) async {
  await db.transaction(() async {
    await m.createTable(schema.sidenav);
  });
}
