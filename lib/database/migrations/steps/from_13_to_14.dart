import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom13To14(
  AppDatabase db,
  Migrator m,
  Schema14 schema,
) async {
  await m.createTable(schema.bookmarks);
}
