import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom12To13(
  AppDatabase db,
  Migrator m,
  Schema13 schema,
) async {
  await db.transaction(() async {
    await m.alterTable(
      TableMigration(
        schema.chapters,
        newColumns: [
          schema.chapters.totalReads,
          schema.chapters.remotePagesRead,
        ],
      ),
    );
  });
}
