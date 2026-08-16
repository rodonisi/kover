// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kover/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/library_type.dart';
import 'package:kover/models/enums/publication_status.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;

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
      await db.close();

      final migratedDb = v4.DatabaseAtV4(schema.newConnection());
      final libraries = await migratedDb
          .select(migratedDb.libraries)
          .getSingle();
      expect(libraries.id, 1);
      expect(libraries.name, 'Test Library');
      expect(libraries.type, LibraryType.book.name);
      expect(libraries.includeInDashboard, 1);
      expect(libraries.includeInRecommended, 1);
      expect(libraries.includeInSearch, 1);
      expect(libraries.defaultLanguage, null);
      expect(libraries.lastScanned, null);

      await migratedDb.close();
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
      await db.close();

      final migratedDb = v7.DatabaseAtV7(schema.newConnection());
      final chapters = await migratedDb.select(migratedDb.chapters).get();
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
      expect(chapters.first.format, Format.epub.name);
      expect(chapters.first.remoteLastRead, null);

      await migratedDb.close();
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
      await db.close();

      final migratedDb = v7.DatabaseAtV7(schema.newConnection());
      final series = await migratedDb.select(migratedDb.series).get();
      expect(series, hasLength(1));
      expect(series.first.id, 1);
      expect(series.first.libraryId, 1);
      expect(series.first.name, 'Test Series');
      expect(series.first.format, Format.epub.name);
      expect(series.first.remoteLastRead, null);

      await migratedDb.close();
    });
  });

  group('from 8 to 9', () {
    test('does not corrupt existing series metadata', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb
          .into(oldDb.seriesMetadata)
          .insert(
            v8.SeriesMetadataCompanion.insert(
              seriesId: 1,
              releaseYear: 2020,
              language: 'en',
              ageRating: const Value(5),
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();

      final migratedDb = v9.DatabaseAtV9(schema.newConnection());
      final seriesMetadata = await migratedDb
          .select(migratedDb.seriesMetadata)
          .get();
      expect(seriesMetadata, hasLength(1));
      expect(seriesMetadata.first.seriesId, 1);
      expect(seriesMetadata.first.releaseYear, 2020);
      expect(seriesMetadata.first.language, 'en');
      expect(seriesMetadata.first.maxCount, 0);
      expect(seriesMetadata.first.totalCount, 0);
      expect(
        seriesMetadata.first.publicationStatus,
        PublicationStatus.unknown.name,
      );
      expect(seriesMetadata.first.webLinks, null);
      expect(seriesMetadata.first.ageRating, 5);

      await migratedDb.close();
    });

    test('does not corrupt existing people', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb
          .into(oldDb.people)
          .insert(
            v8.PeopleCompanion.insert(
              id: const Value(1),
              name: 'Test Person',
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();

      final migratedDb = v9.DatabaseAtV9(schema.newConnection());
      final people = await migratedDb.select(migratedDb.people).get();
      expect(people, hasLength(1));
      expect(people.first.id, 1);
      expect(people.first.name, 'Test Person');
      expect(people.first.primaryColor, null);
      expect(people.first.secondaryColor, null);
      expect(people.first.description, null);
      expect(people.first.aliases, null);

      await migratedDb.close();
    });

    test('does not corrupt existing chapters', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb
          .into(oldDb.chapters)
          .insert(
            v8.ChaptersCompanion.insert(
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
      await oldDb
          .into(oldDb.chapters)
          .insert(
            v8.ChaptersCompanion.insert(
              id: const Value(2),
              volumeId: 1,
              seriesId: 1,
              title: const Value('Test Chapter 2'),
              minNumber: 2.0,
              maxNumber: 2.0,
              pages: 42,
              wordCount: 42,
              sortOrder: 2.0,
              format: 'epub',
              ageRating: const Value(8),
              releaseDate: DateTime.now().millisecondsSinceEpoch,
              created: DateTime.now().millisecondsSinceEpoch,
              lastModified: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();

      final migratedDb = v9.DatabaseAtV9(schema.newConnection());
      final chapters = await migratedDb.select(migratedDb.chapters).get();
      expect(chapters, hasLength(2));
      expect(chapters.first.id, 1);
      expect(chapters.first.volumeId, 1);
      expect(chapters.first.seriesId, 1);
      expect(chapters.first.title, 'Test Chapter');
      expect(chapters.first.minNumber, 1.0);
      expect(chapters.first.maxNumber, 1.0);
      expect(chapters.first.pages, 42);
      expect(chapters.first.wordCount, 42);
      expect(chapters.first.sortOrder, 1.0);
      expect(chapters.first.format, Format.epub.name);
      expect(chapters.first.ageRating, 0);
      expect(
        chapters.first.publicationStatus,
        PublicationStatus.unknown.name,
      );
      expect(chapters.first.webLinks, null);
      expect(chapters.last.id, 2);
      expect(chapters.last.ageRating, 8);

      await migratedDb.close();
    });

    test('migrates series people roles and allows multiple roles', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb
          .into(oldDb.seriesPeopleRoles)
          .insert(
            v8.SeriesPeopleRolesCompanion.insert(
              seriesMetadataId: 1,
              personId: 1,
              role: 'writer',
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();

      final migratedDb = v9.DatabaseAtV9(schema.newConnection());
      final roles = await migratedDb.select(migratedDb.seriesPeopleRoles).get();
      expect(roles, hasLength(1));
      expect(roles.first.seriesMetadataId, 1);
      expect(roles.first.personId, 1);
      expect(roles.first.role, 'writer');

      await migratedDb
          .into(migratedDb.seriesPeopleRoles)
          .insert(
            v9.SeriesPeopleRolesCompanion.insert(
              seriesMetadataId: 1,
              personId: 1,
              role: 'colorist',
            ),
          );
      final rolesAfter = await migratedDb
          .select(migratedDb.seriesPeopleRoles)
          .get();
      expect(rolesAfter, hasLength(2));

      await migratedDb.close();
    });
  });
}
