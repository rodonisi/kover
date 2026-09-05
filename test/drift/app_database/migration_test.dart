// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:html/parser.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/migrations/steps/from_9_to_10.dart';
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
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v13.dart' as v13;

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

    test('resets series last synced', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb
          .into(oldDb.series)
          .insert(
            v8.SeriesCompanion.insert(
              id: const Value(1),
              libraryId: 1,
              name: 'Test Series',
              format: 'epub',
              created: DateTime.now().millisecondsSinceEpoch,
              lastSynced: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();

      final migratedDb = v9.DatabaseAtV9(schema.newConnection());
      final series = await migratedDb.select(migratedDb.series).get();
      expect(series, hasLength(1));
      expect(series.first.id, 1);
      expect(series.first.lastSynced, null);

      await migratedDb.close();
    });

    test('clears series people roles', () async {
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
      expect(roles, hasLength(0));

      await migratedDb.close();
    });
  });

  group('from 9 to 10', () {
    // Font payloads are opaque to the migration; headers only mimic real
    // font files.
    final font = Uint8List.fromList([0, 1, 2, 3]);
    final font2 = Uint8List.fromList([4, 2]);

    Map<String, dynamic> legacyPage({
      String root =
          '<style>@font-face { font-family: TestFont; '
          'src: url(fonts://t/regular.ttf); }</style>'
          '<p>hello</p>',
      Object? fonts,
    }) => {
      'root': root,
      'styles': <String, Map<String, String>>{},
      'fonts': fonts ?? <String, dynamic>{},
    };

    Future<void> insertEpubChapter(
      v9.DatabaseAtV9 oldDb,
      int id, {
      String format = 'epub',
    }) => oldDb
        .into(oldDb.chapters)
        .insert(
          v9.ChaptersCompanion.insert(
            id: Value(id),
            volumeId: 1,
            seriesId: 1,
            minNumber: 1.0,
            maxNumber: 1.0,
            pages: 1,
            wordCount: 0,
            sortOrder: 1.0,
            format: format,
            ageRating: 0,
            publicationStatus: PublicationStatus.unknown.name,
            releaseDate: DateTime.now().millisecondsSinceEpoch,
            created: DateTime.now().millisecondsSinceEpoch,
            lastModified: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    Future<void> insertLegacyPage(
      v9.DatabaseAtV9 oldDb,
      int chapterId,
      int page,
      Uint8List data,
    ) => oldDb
        .into(oldDb.downloadedPages)
        .insert(
          v9.DownloadedPagesCompanion.insert(
            chapterId: chapterId,
            page: page,
            data: data,
          ),
        );

    Future<v10.DatabaseAtV10> migrateTo10(dynamic schema) async {
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);
      await db.close();
      return v10.DatabaseAtV10(schema.newConnection());
    }

    test('moves embedded epub page fonts into the fonts table', () async {
      final page = legacyPage(
        root: parseFragment(
          '<style>@font-face { font-family: TestFont; '
          'src: url(fonts://t/regular.ttf); }</style>'
          '<style>@font-face { font-family: TestFont; font-weight: 700; '
          'src: url(fonts://t/bold.ttf); }</style>'
          '<p>hello</p>',
        ).outerHtml,
        fonts: {
          'TestFont': [base64Encode(font), base64Encode(font2)],
        },
      );

      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      await insertEpubChapter(oldDb, 1);
      await insertLegacyPage(oldDb, 1, 0, pageBlobConverter.toSql(page));
      await oldDb.close();

      final migratedDb = await migrateTo10(schema);

      final fonts = await migratedDb.select(migratedDb.fonts).get();
      expect(fonts, hasLength(2));

      final regular = fonts.firstWhere(
        (f) => f.url == 'fonts://t/regular.ttf',
      );
      expect(regular.family, 'TestFont');
      expect(regular.weight, null);
      expect(regular.data, font);

      final bold = fonts.firstWhere((f) => f.url == 'fonts://t/bold.ttf');
      expect(bold.family, 'TestFont');
      expect(bold.weight, 700);
      expect(bold.data, font2);

      final storedPage = await migratedDb
          .select(migratedDb.downloadedPages)
          .getSingle();
      final rewritten = pageBlobConverter.fromSql(storedPage.data);
      expect(rewritten['root'], page['root']);
      expect(rewritten['fonts'], [
        {'family': 'TestFont', 'weight': null, 'url': 'fonts://t/regular.ttf'},
        {'family': 'TestFont', 'weight': 700, 'url': 'fonts://t/bold.ttf'},
      ]);

      await migratedDb.close();
    });

    test('rewrites pages without embedded fonts to the new format', () async {
      final page = legacyPage(root: '<p>hello</p>');

      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      await insertEpubChapter(oldDb, 1);
      await insertLegacyPage(oldDb, 1, 0, pageBlobConverter.toSql(page));
      await oldDb.close();

      final migratedDb = await migrateTo10(schema);

      expect(await migratedDb.select(migratedDb.fonts).get(), isEmpty);

      final storedPage = await migratedDb
          .select(migratedDb.downloadedPages)
          .getSingle();
      final rewritten = pageBlobConverter.fromSql(storedPage.data);
      expect(rewritten['fonts'], isEmpty);

      await migratedDb.close();
    });

    test(
      'drops fonts from pages whose only fonts are unsupported formats',
      () async {
        final page = legacyPage(
          root:
              '<style>@font-face { font-family: TestFont; '
              'src: url(fonts://t/book.woff); }</style>'
              '<p>hello</p>',
          fonts: {
            'TestFont': [base64Encode(font)],
          },
        );

        final schema = await verifier.schemaAt(9);
        final oldDb = v9.DatabaseAtV9(schema.newConnection());
        await insertEpubChapter(oldDb, 1);
        await insertLegacyPage(oldDb, 1, 0, pageBlobConverter.toSql(page));
        await oldDb.close();

        final migratedDb = await migrateTo10(schema);

        expect(await migratedDb.select(migratedDb.fonts).get(), isEmpty);

        final storedPage = await migratedDb
            .select(migratedDb.downloadedPages)
            .getSingle();
        final rewritten = pageBlobConverter.fromSql(storedPage.data);
        expect(rewritten['fonts'], isEmpty);

        await migratedDb.close();
      },
    );

    test('skips undecodable blobs and keeps migrating', () async {
      final page = legacyPage(root: '<p>hello</p>');

      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      await insertEpubChapter(oldDb, 1);
      await insertLegacyPage(
        oldDb,
        1,
        0,
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      );
      await insertLegacyPage(oldDb, 1, 1, pageBlobConverter.toSql(page));
      await oldDb.close();

      final migratedDb = await migrateTo10(schema);

      expect(await migratedDb.select(migratedDb.fonts).get(), isEmpty);

      final pages = await migratedDb.select(migratedDb.downloadedPages).get();
      expect(pages, hasLength(2));

      // The corrupt row is left exactly as it was stored.
      final corrupt = pages.singleWhere((p) => p.page == 0);
      expect(corrupt.data, [0x89, 0x50, 0x4e, 0x47]);

      // The decodable row is rewritten to the new format.
      final rewritten = pages.singleWhere((p) => p.page == 1);
      expect(
        pageBlobConverter.fromSql(rewritten.data)['fonts'],
        isEmpty,
      );

      await migratedDb.close();
    });

    test('leaves downloads of other formats untouched', () async {
      final rawBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);

      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      await insertEpubChapter(oldDb, 2, format: 'archive');
      await insertLegacyPage(oldDb, 2, 0, rawBytes);
      await oldDb.close();

      final migratedDb = await migrateTo10(schema);

      expect(await migratedDb.select(migratedDb.fonts).get(), isEmpty);

      final storedPage = await migratedDb
          .select(migratedDb.downloadedPages)
          .getSingle();
      expect(storedPage.data, rawBytes);

      await migratedDb.close();
    });
  });

  group('from 12 to 13', () {
    test('does not corrupt existing chapters', () async {
      final schema = await verifier.schemaAt(12);
      final oldDb = v12.DatabaseAtV12(schema.newConnection());
      await oldDb
          .into(oldDb.chapters)
          .insert(
            v12.ChaptersCompanion.insert(
              id: const Value(1),
              volumeId: 1,
              seriesId: 1,
              format: Format.epub.name,
              minNumber: 0,
              maxNumber: 0,
              sortOrder: 0,
              pages: 0,
              wordCount: 0,
              ageRating: 0,
              releaseDate: DateTime.now().millisecondsSinceEpoch,
              publicationStatus: PublicationStatus.unknown.name,
              created: DateTime.now().millisecondsSinceEpoch,
              lastModified: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 13);
      await db.close();

      final migratedDb = v13.DatabaseAtV13(schema.newConnection());
      final chapters = await migratedDb.select(migratedDb.chapters).get();

      expect(chapters, hasLength(1));
      expect(chapters.first.id, 1);
      expect(chapters.first.volumeId, 1);
      expect(chapters.first.seriesId, 1);
      expect(chapters.first.format, Format.epub.name);
      expect(chapters.first.minNumber, 0);
      expect(chapters.first.maxNumber, 0);
      expect(chapters.first.sortOrder, 0);
      expect(chapters.first.pages, 0);
      expect(chapters.first.wordCount, 0);
      expect(chapters.first.ageRating, 0);
      expect(chapters.first.publicationStatus, PublicationStatus.unknown.name);

      expect(chapters.first.totalReads, 0);
      expect(chapters.first.remoteLastRead, null);

      await migratedDb.close();
    });
  });
}
