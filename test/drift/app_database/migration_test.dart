// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kover/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/enums/library_type.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group('from 3 to 4 ', () {
    test('does not corrupt existing data', () async {
      final schema = await verifier.schemaAt(3);
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await oldDb
          .into(oldDb.libraries)
          .insert(
            v3.LibrariesCompanion.insert(
              id: const Value(1),
              name: 'Test Library',
              type: 'book',
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      final libraries = await db.select(db.libraries).get();
      expect(libraries, hasLength(1));
      expect(libraries.first.id, 1);
      expect(libraries.first.name, 'Test Library');
      expect(libraries.first.type, LibraryType.book);
      expect(libraries.first.includeInDashboard, true);
      expect(libraries.first.includeInRecommended, true);
      expect(libraries.first.includeInSearch, true);
      expect(libraries.first.defaultLanguage, null);
      expect(libraries.first.lastScanned, null);

      await db.close();
    });
  });
}
