import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom4To5(AppDatabase db, Migrator m, Schema5 schema) async {
  await db.transaction(() async {
    await m.createTable(schema.readingLists);
    await m.createTable(schema.readingListsChapters);
    await m.createTable(schema.readingListCovers);
  });
}
