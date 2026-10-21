import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/library_type.dart';
import 'package:kover/models/enums/publication_status.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertLibrary(int id) async {
    await database
        .into(database.libraries)
        .insert(
          LibrariesCompanion.insert(
            id: Value(id),
            name: 'lib$id',
            type: LibraryType.manga,
          ),
        );
  }

  Future<void> insertSeries(
    int id, {
    DateTime? lastSynced,
    DateTime? lastChapterAdded,
    DateTime? remoteLastRead,
    int pages = 0,
  }) async {
    await database
        .into(database.series)
        .insert(
          SeriesCompanion(
            id: Value(id),
            libraryId: const Value(1),
            name: Value('name$id'),
            format: const Value(Format.epub),
            created: Value(DateTime.now()),
            pages: Value(pages),
            lastChapterAdded: Value.absentIfNull(lastChapterAdded),
            lastSynced: Value.absentIfNull(lastSynced),
            remoteLastRead: Value.absentIfNull(remoteLastRead),
          ),
        );
  }

  Future<void> insertChapter(
    int id, {
    required int seriesId,
    Format format = .epub,
  }) async {
    await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: Value(id),
            volumeId: 0,
            seriesId: seriesId,
            format: format,
            minNumber: 0,
            maxNumber: 0,
            sortOrder: 0,
            ageRating: AgeRating.unknown,
            publicationStatus: PublicationStatus.unknown,
            wordCount: 0,
            releaseDate: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            pages: 3,
          ),
        );
  }

  Future<void> insertDownloadedPage(int chapterId) async {
    await database
        .into(database.downloadedPages)
        .insert(
          DownloadedPagesCompanion.insert(
            chapterId: chapterId,
            page: 0,
            data: Uint8List.fromList([]),
          ),
        );
  }

  Future<void> insertBookmark({
    required int seriesId,
    required int chapterId,
    bool removed = false,
  }) async {
    await database
        .into(database.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            seriesId: seriesId,
            volumeId: 0,
            chapterId: chapterId,
            page: 0,
            imageOffset: const Value(0),
            removed: Value(removed),
          ),
        );
  }

  Future<void> insertReadingProgress({
    required int chapterId,
    required int seriesId,
    required int pagesRead,
  }) async {
    await database
        .into(database.readingProgress)
        .insert(
          ReadingProgressCompanion.insert(
            chapterId: Value(chapterId),
            volumeId: 0,
            seriesId: seriesId,
            libraryId: 1,
            pagesRead: Value(pagesRead),
            lastModified: Value(DateTime.now()),
          ),
        );
  }

  ChapterWithRelationsCompanion chapterWithProgress({
    required int id,
    required int seriesId,
    required int pagesRead,
    Format format = Format.epub,
    DateTime? remoteLastRead,
  }) {
    return ChapterWithRelationsCompanion(
      chapter: ChaptersCompanion(
        id: Value(id),
        volumeId: const Value(0),
        seriesId: Value(seriesId),
        format: Value(format),
        minNumber: const Value(0),
        maxNumber: const Value(0),
        sortOrder: const Value(0),
        pages: const Value(10),
        wordCount: const Value(0),
        ageRating: const Value(AgeRating.unknown),
        releaseDate: Value(DateTime.now()),
        publicationStatus: const Value(PublicationStatus.unknown),
        created: Value(DateTime.now()),
        lastModified: Value(DateTime.now()),
        remotePagesRead: Value(pagesRead),
        remoteLastRead: Value.absentIfNull(remoteLastRead),
      ),
      writers: const [],
      coverArtists: const [],
      publishers: const [],
      characters: const [],
      pencillers: const [],
      inkers: const [],
      imprints: const [],
      colorists: const [],
      letterers: const [],
      editors: const [],
      translators: const [],
      teams: const [],
      locations: const [],
      genres: const [],
      tags: const [],
    );
  }

  SeriesDetailCompanions detailWithChapters(
    List<ChapterWithRelationsCompanion> chapters,
  ) {
    return SeriesDetailCompanions(
      seriesId: 1,
      storyline: const [],
      specials: const [],
      chapters: chapters,
      volumes: const [],
    );
  }

  group('SeriesDao', () {
    group('getOutdatedDetailsSeriesIds', () {
      test(
        'returns only series that are never synced or changed since sync',
        () async {
          await insertLibrary(1);

          final synced = DateTime(2024, 1, 1, 12);

          // never synced -> selected
          await insertSeries(1, lastSynced: null);
          // synced, no changes -> not selected
          await insertSeries(
            2,
            lastSynced: synced,
            lastChapterAdded: synced.subtract(const Duration(days: 1)),
          );
          // new chapter since sync -> selected
          await insertSeries(
            3,
            lastSynced: synced,
            lastChapterAdded: synced.add(const Duration(hours: 1)),
          );
          // new read since sync -> selected
          await insertSeries(
            4,
            lastSynced: synced,
            lastChapterAdded: synced,
            remoteLastRead: synced.add(const Duration(hours: 2)),
          );
          // unchanged -> not selected
          await insertSeries(
            5,
            lastSynced: synced,
            lastChapterAdded: synced,
            remoteLastRead: synced,
          );

          final result = await database.seriesDao.getOutdatedDetailsSeriesIds();

          expect(result.toSet(), equals({1, 3, 4}));
        },
      );
    });

    group('allSeries downloadedOnly', () {
      test('returns only series with a downloaded page', () async {
        await insertLibrary(1);

        await insertSeries(1);
        await insertSeries(2);
        await insertSeries(3);

        await insertChapter(10, seriesId: 1);
        await insertChapter(20, seriesId: 2);

        await insertDownloadedPage(10);

        final result = await database.seriesDao
            .allSeries(downloadedOnly: true)
            .get();

        expect(result.map((s) => s.id).toSet(), equals({1}));
      });

      test('emits again when a page is downloaded', () async {
        await insertLibrary(1);

        await insertSeries(1);
        await insertSeries(2);
        await insertChapter(10, seriesId: 1);
        await insertChapter(20, seriesId: 2);

        final stream = database.seriesDao
            .allSeries(downloadedOnly: true)
            .watch()
            .map((rows) => rows.map((s) => s.id).toSet());

        final completer = Completer<Set<int>>();
        final subscription = stream.listen((ids) {
          if (ids.contains(2) && !completer.isCompleted) {
            completer.complete(ids);
          }
        });

        await insertDownloadedPage(20);

        expect(
          await completer.future,
          equals({2}),
        );

        await subscription.cancel();
      });
    });

    group('allSeries bookmarkedOnly', () {
      test(
        'returns only series with a non-removed bookmark on an image chapter',
        () async {
          await insertLibrary(1);

          await insertSeries(1);
          await insertSeries(2);
          await insertSeries(3);

          await insertChapter(10, seriesId: 1, format: .image);
          await insertChapter(20, seriesId: 2, format: .epub);
          await insertChapter(30, seriesId: 3, format: .image);

          await insertBookmark(seriesId: 1, chapterId: 10);
          await insertBookmark(seriesId: 2, chapterId: 20);
          await insertBookmark(seriesId: 3, chapterId: 30, removed: true);

          final result = await database.seriesDao
              .allSeries(bookmarkedOnly: true)
              .get();

          expect(result.map((s) => s.id).toSet(), equals({1}));
        },
      );
    });

    group('watchOnDeck downloadedOnly', () {
      test('returns only on deck series with a downloaded page', () async {
        await insertLibrary(1);

        await insertSeries(1, pages: 10);
        await insertSeries(2, pages: 10);

        await insertChapter(10, seriesId: 1);
        await insertChapter(20, seriesId: 2);

        await insertReadingProgress(
          chapterId: 10,
          seriesId: 1,
          pagesRead: 2,
        );
        await insertReadingProgress(
          chapterId: 20,
          seriesId: 2,
          pagesRead: 2,
        );

        await insertDownloadedPage(10);

        final result = await database.seriesDao
            .watchOnDeck(downloadedOnly: true)
            .first;

        expect(result.map((s) => s.id).toSet(), equals({1}));
      });
    });

    group('upsertDetailsBatch progress', () {
      test('seeds progress for chapters with read pages', () async {
        await insertLibrary(1);
        await insertSeries(1);

        final remoteLastRead = DateTime(2024, 1, 1);

        await database.seriesDao.upsertDetailsBatch([
          detailWithChapters([
            chapterWithProgress(
              id: 10,
              seriesId: 1,
              pagesRead: 2,
              remoteLastRead: remoteLastRead,
            ),
            chapterWithProgress(id: 20, seriesId: 1, pagesRead: 0),
            chapterWithProgress(
              id: 30,
              seriesId: 1,
              pagesRead: 3,
              format: Format.image,
            ),
          ]),
        ]);

        final progress = await database.select(database.readingProgress).get();

        expect(progress, hasLength(2));

        final epub = progress.singleWhere((p) => p.chapterId == 10);
        expect(epub.seriesId, 1);
        expect(epub.libraryId, 1);
        expect(epub.pagesRead, 2);
        expect(epub.lastModified, remoteLastRead);

        final image = progress.singleWhere((p) => p.chapterId == 30);
        expect(image.pagesRead, 3);
      });

      test('does not overwrite existing local progress', () async {
        await insertLibrary(1);
        await insertSeries(1);
        await insertReadingProgress(
          chapterId: 10,
          seriesId: 1,
          pagesRead: 1,
        );

        await database.seriesDao.upsertDetailsBatch([
          detailWithChapters([
            chapterWithProgress(id: 10, seriesId: 1, pagesRead: 2),
          ]),
        ]);

        final progress = await database
            .select(database.readingProgress)
            .getSingle();

        expect(progress.pagesRead, 1);
      });
    });
  });
}
