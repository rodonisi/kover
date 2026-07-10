// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kover/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/library_type.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;

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

  group('from 6 to 7', () {
    test('does not corrupt existing chapters', () async {
      final schema = await verifier.schemaAt(6);
      final oldDb = v6.DatabaseAtV6(schema.newConnection());
      await oldDb
          .into(oldDb.chapters)
          .insert(
            v6.ChaptersCompanion.insert(
              id: const Value(1),
              volumeId: 1,
              seriesId: 1,
              title: const Value('Test Chapter'),
              minNumber: 1.0,
              maxNumber: 1.0,
              pages: 42,
              wordCount: 42,
              sortOrder: 1.0,
              format: 'epub',
              releaseDate: DateTime.now().millisecondsSinceEpoch,
              created: DateTime.now().millisecondsSinceEpoch,
              lastModified: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);

      final chapters = await db.select(db.chapters).get();
      expect(chapters, hasLength(1));
      expect(chapters.first.id, 1);
      expect(chapters.first.volumeId, 1);
      expect(chapters.first.seriesId, 1);
      expect(chapters.first.title, 'Test Chapter');
      expect(chapters.first.minNumber, 1.0);
      expect(chapters.first.maxNumber, 1.0);
      expect(chapters.first.pages, 42);
      expect(chapters.first.wordCount, 42);
      expect(chapters.first.sortOrder, 1.0);
      expect(chapters.first.format, Format.epub);
      expect(chapters.first.remoteLastRead, null);

      await db.close();
    });

    test('does not corrupt existing series', () async {
      final schema = await verifier.schemaAt(6);
      final oldDb = v6.DatabaseAtV6(schema.newConnection());
      await oldDb
          .into(oldDb.series)
          .insert(
            v6.SeriesCompanion.insert(
              id: const Value(1),
              libraryId: 1,
              name: 'Test Series',
              format: 'epub',
              created: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);

      final series = await db.select(db.series).get();
      expect(series, hasLength(1));
      expect(series.first.id, 1);
      expect(series.first.libraryId, 1);
      expect(series.first.name, 'Test Series');
      expect(series.first.format, Format.epub);
      expect(series.first.remoteLastRead, null);

      await db.close();
    });
  });
}
