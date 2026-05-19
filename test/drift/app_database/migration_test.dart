// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kover/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldRiverpodStorageData = <v1.RiverpodStorageData>[];
    final expectedNewRiverpodStorageData = <v2.RiverpodStorageData>[];

    final oldLibrariesData = <v1.LibrariesData>[];
    final expectedNewLibrariesData = <v2.LibrariesData>[];

    final oldSeriesData = <v1.SeriesData>[];
    final expectedNewSeriesData = <v2.SeriesData>[];

    final oldSeriesMetadataData = <v1.SeriesMetadataData>[];
    final expectedNewSeriesMetadataData = <v2.SeriesMetadataData>[];

    final oldSeriesCoversData = <v1.SeriesCoversData>[];
    final expectedNewSeriesCoversData = <v2.SeriesCoversData>[];

    final oldPeopleData = <v1.PeopleData>[];
    final expectedNewPeopleData = <v2.PeopleData>[];

    final oldGenresData = <v1.GenresData>[];
    final expectedNewGenresData = <v2.GenresData>[];

    final oldTagsData = <v1.TagsData>[];
    final expectedNewTagsData = <v2.TagsData>[];

    final oldSeriesPeopleRolesData = <v1.SeriesPeopleRolesData>[];
    final expectedNewSeriesPeopleRolesData = <v2.SeriesPeopleRolesData>[];

    final oldSeriesGenresData = <v1.SeriesGenresData>[];
    final expectedNewSeriesGenresData = <v2.SeriesGenresData>[];

    final oldSeriesTagsData = <v1.SeriesTagsData>[];
    final expectedNewSeriesTagsData = <v2.SeriesTagsData>[];

    final oldVolumesData = <v1.VolumesData>[];
    final expectedNewVolumesData = <v2.VolumesData>[];

    final oldVolumeCoversData = <v1.VolumeCoversData>[];
    final expectedNewVolumeCoversData = <v2.VolumeCoversData>[];

    final oldChaptersData = <v1.ChaptersData>[];
    final expectedNewChaptersData = <v2.ChaptersData>[];

    final oldChapterCoversData = <v1.ChapterCoversData>[];
    final expectedNewChapterCoversData = <v2.ChapterCoversData>[];

    final oldReadingProgressData = <v1.ReadingProgressData>[];
    final expectedNewReadingProgressData = <v2.ReadingProgressData>[];

    final oldBookChaptersData = <v1.BookChaptersData>[];
    final expectedNewBookChaptersData = <v2.BookChaptersData>[];

    final oldWantToReadData = <v1.WantToReadData>[];
    final expectedNewWantToReadData = <v2.WantToReadData>[];

    final oldDownloadedPagesData = <v1.DownloadedPagesData>[];
    final expectedNewDownloadedPagesData = <v2.DownloadedPagesData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.riverpodStorage, oldRiverpodStorageData);
        batch.insertAll(oldDb.libraries, oldLibrariesData);
        batch.insertAll(oldDb.series, oldSeriesData);
        batch.insertAll(oldDb.seriesMetadata, oldSeriesMetadataData);
        batch.insertAll(oldDb.seriesCovers, oldSeriesCoversData);
        batch.insertAll(oldDb.people, oldPeopleData);
        batch.insertAll(oldDb.genres, oldGenresData);
        batch.insertAll(oldDb.tags, oldTagsData);
        batch.insertAll(oldDb.seriesPeopleRoles, oldSeriesPeopleRolesData);
        batch.insertAll(oldDb.seriesGenres, oldSeriesGenresData);
        batch.insertAll(oldDb.seriesTags, oldSeriesTagsData);
        batch.insertAll(oldDb.volumes, oldVolumesData);
        batch.insertAll(oldDb.volumeCovers, oldVolumeCoversData);
        batch.insertAll(oldDb.chapters, oldChaptersData);
        batch.insertAll(oldDb.chapterCovers, oldChapterCoversData);
        batch.insertAll(oldDb.readingProgress, oldReadingProgressData);
        batch.insertAll(oldDb.bookChapters, oldBookChaptersData);
        batch.insertAll(oldDb.wantToRead, oldWantToReadData);
        batch.insertAll(oldDb.downloadedPages, oldDownloadedPagesData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewRiverpodStorageData,
          await newDb.select(newDb.riverpodStorage).get(),
        );
        expect(
          expectedNewLibrariesData,
          await newDb.select(newDb.libraries).get(),
        );
        expect(expectedNewSeriesData, await newDb.select(newDb.series).get());
        expect(
          expectedNewSeriesMetadataData,
          await newDb.select(newDb.seriesMetadata).get(),
        );
        expect(
          expectedNewSeriesCoversData,
          await newDb.select(newDb.seriesCovers).get(),
        );
        expect(expectedNewPeopleData, await newDb.select(newDb.people).get());
        expect(expectedNewGenresData, await newDb.select(newDb.genres).get());
        expect(expectedNewTagsData, await newDb.select(newDb.tags).get());
        expect(
          expectedNewSeriesPeopleRolesData,
          await newDb.select(newDb.seriesPeopleRoles).get(),
        );
        expect(
          expectedNewSeriesGenresData,
          await newDb.select(newDb.seriesGenres).get(),
        );
        expect(
          expectedNewSeriesTagsData,
          await newDb.select(newDb.seriesTags).get(),
        );
        expect(expectedNewVolumesData, await newDb.select(newDb.volumes).get());
        expect(
          expectedNewVolumeCoversData,
          await newDb.select(newDb.volumeCovers).get(),
        );
        expect(
          expectedNewChaptersData,
          await newDb.select(newDb.chapters).get(),
        );
        expect(
          expectedNewChapterCoversData,
          await newDb.select(newDb.chapterCovers).get(),
        );
        expect(
          expectedNewReadingProgressData,
          await newDb.select(newDb.readingProgress).get(),
        );
        expect(
          expectedNewBookChaptersData,
          await newDb.select(newDb.bookChapters).get(),
        );
        expect(
          expectedNewWantToReadData,
          await newDb.select(newDb.wantToRead).get(),
        );
        expect(
          expectedNewDownloadedPagesData,
          await newDb.select(newDb.downloadedPages).get(),
        );
      },
    );
  });
}
