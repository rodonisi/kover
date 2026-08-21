import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom2To3(AppDatabase db, Migrator m, Schema3 schema) async {
  await db.transaction(() async {
    await m.createTable(schema.collections);
    await m.createTable(schema.collectionSeries);
    await m.createTable(schema.collectionCovers);
  });
}
