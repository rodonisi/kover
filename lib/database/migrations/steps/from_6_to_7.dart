import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom6To7(AppDatabase db, Migrator m, Schema7 schema) async {
  await db.transaction(() async {
    await m.alterTable(
      TableMigration(
        schema.chapters,
        newColumns: [
          schema.chapters.remoteLastRead,
        ],
      ),
    );
    await m.alterTable(
      TableMigration(
        schema.series,
        newColumns: [
          schema.series.remoteLastRead,
        ],
      ),
    );
  });
}
