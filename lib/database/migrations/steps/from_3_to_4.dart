import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';

Future<void> migrateFrom3To4(AppDatabase db, Migrator m, Schema4 schema) async {
  await db.transaction(() async {
    await m.alterTable(
      TableMigration(
        schema.libraries,
        newColumns: [
          schema.libraries.includeInDashboard,
          schema.libraries.includeInRecommended,
          schema.libraries.includeInSearch,
          schema.libraries.defaultLanguage,
          schema.libraries.lastScanned,
        ],
      ),
    );
  });
}
