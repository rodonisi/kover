import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';

Future<void> migrateFrom1To2(AppDatabase db, Migrator m, Schema2 schema) async {
  // Clear legacy credentials entry from database if present.
  final rows = await (db.delete(
    db.riverpodStorage,
  )..where((tbl) => tbl.key.equals(Credentials.persistKey))).go();

  if (rows > 0) {
    await db.vacuum();
  }

  await db.transaction(() async {
    await m.createTable(schema.serverSettings);
  });
}
