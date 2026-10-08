import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db
        .into(db.series)
        .insert(
          SeriesCompanion.insert(
            id: const Value(1),
            libraryId: 1,
            name: 'S',
            format: Format.epub,
            created: DateTime.now(),
          ),
        );
    await db
        .into(db.volumes)
        .insert(
          VolumesCompanion.insert(
            id: const Value(1),
            seriesId: 1,
            minNumber: 0,
            maxNumber: 0,
            pages: 10,
            created: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: const Value(1),
            volumeId: 1,
            seriesId: 1,
            format: Format.epub,
            minNumber: 0,
            maxNumber: 0,
            sortOrder: 0,
            ageRating: AgeRating.unknown,
            publicationStatus: PublicationStatus.unknown,
            wordCount: 0,
            releaseDate: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            pages: 10,
          ),
        );
  });

  tearDown(() => db.close());

  BookmarksCompanion entry({
    int page = 0,
    String xPath = '',
    int imageOffset = -1,
  }) {
    return BookmarksCompanion.insert(
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: page,
      xPath: Value(xPath),
      imageOffset: Value(imageOffset),
    );
  }

  BookmarksCompanion bookmark({
    required int seriesId,
    required int volumeId,
    required int chapterId,
    int page = 0,
  }) {
    return BookmarksCompanion.insert(
      seriesId: seriesId,
      volumeId: volumeId,
      chapterId: chapterId,
      page: page,
    );
  }

  Future<void> insertSeries(int id, String name) {
    return db
        .into(db.series)
        .insert(
          SeriesCompanion.insert(
            id: Value(id),
            libraryId: 1,
            name: name,
            format: Format.epub,
            created: DateTime.now(),
          ),
        );
  }

  Future<void> insertVolume(int id, int seriesId) {
    return db
        .into(db.volumes)
        .insert(
          VolumesCompanion.insert(
            id: Value(id),
            seriesId: seriesId,
            minNumber: 0,
            maxNumber: 0,
            pages: 10,
            created: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );
  }

  Future<void> insertChapter({
    required int id,
    required int volumeId,
    required int seriesId,
    double sortOrder = 0,
  }) {
    return db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: Value(id),
            volumeId: volumeId,
            seriesId: seriesId,
            format: Format.epub,
            minNumber: 0,
            maxNumber: 0,
            sortOrder: sortOrder,
            ageRating: AgeRating.unknown,
            publicationStatus: PublicationStatus.unknown,
            wordCount: 0,
            releaseDate: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            pages: 10,
          ),
        );
  }

  test('upsertByNaturalKey does not duplicate the same key', () async {
    await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.upsertByNaturalKey(entry());
    final all = await db.select(db.bookmarks).get();
    expect(all, hasLength(1));
  });

  test('upsertByNaturalKey updates an existing tombstone', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.markRemoved(row.id);
    await db.bookmarkDao.upsertByNaturalKey(
      entry().copyWith(dirty: const Value(true), removed: const Value(false)),
    );
    final all = await db.select(db.bookmarks).get();
    expect(all, hasLength(1));
    expect(all.single.removed, isFalse);
    expect(all.single.dirty, isTrue);
  });

  test('markRemoved sets dirty and removed', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.markRemoved(row.id);
    final stored = await db.bookmarkDao.getByNaturalKey(
      chapterId: 1,
      page: 0,
      xPath: '',
      imageOffset: -1,
    );
    expect(stored!.removed, isTrue);
    expect(stored.dirty, isTrue);
  });

  test('getByLocation finds the row by location ignoring xPath', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(
      entry(xPath: 'xpath-A'),
    );
    final found = await db.bookmarkDao.getByLocation(
      chapterId: 1,
      page: 0,
      imageOffset: -1,
    );
    expect(found, isNot(null));
    expect(found!.id, row.id);
  });

  test('updateById preserves the row id and rewrites metadata', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(
      entry(xPath: 'xpath-A'),
    );
    final updated = await db.bookmarkDao.updateById(
      row.id,
      const BookmarksCompanion(
        xPath: Value('xpath-B'),
        dirty: Value(true),
      ),
    );
    expect(updated.id, row.id);
    expect(updated.xPath, 'xpath-B');
    expect(updated.dirty, isTrue);
    final all = await db.select(db.bookmarks).get();
    expect(all, hasLength(1));
  });

  test('watchChapterBookmarks hides removed rows', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(entry(page: 1));
    await db.bookmarkDao.upsertByNaturalKey(entry(page: 2));
    await db.bookmarkDao.markRemoved(row.id);
    final list = await db.bookmarkDao.watchChapterBookmarks(1).first;
    expect(list.map((b) => b.page), [2]);
  });

  test('getDirtyBookmarks returns dirty rows only', () async {
    await db.bookmarkDao.upsertByNaturalKey(
      entry(page: 1).copyWith(dirty: const Value(true)),
    );
    await db.bookmarkDao.upsertByNaturalKey(entry(page: 2));
    final dirty = await db.bookmarkDao.getDirtyBookmarks();
    expect(dirty.map((b) => b.page), [1]);
  });

  test(
    'watchBookmarkedSeries returns distinct series ordered by name',
    () async {
      await insertSeries(2, 'A');
      await insertVolume(2, 2);
      await insertChapter(id: 2, volumeId: 2, seriesId: 2);

      await db.bookmarkDao.upsertByNaturalKey(entry(page: 1));
      await db.bookmarkDao.upsertByNaturalKey(entry(page: 2));
      await db.bookmarkDao.upsertByNaturalKey(
        bookmark(seriesId: 2, volumeId: 2, chapterId: 2),
      );

      final list = await db.bookmarkDao.watchBookmarkedSeries().first;
      expect(list.map((s) => s.name), ['A', 'S']);
    },
  );

  test('watchBookmarkedSeries ignores removed bookmarks', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.markRemoved(row.id);

    final list = await db.bookmarkDao.watchBookmarkedSeries().first;
    expect(list, isEmpty);
  });

  test(
    'watchBookmarkedChapters returns distinct chapters ordered by sort order',
    () async {
      await insertChapter(id: 2, volumeId: 1, seriesId: 1, sortOrder: 2);
      await insertChapter(id: 3, volumeId: 1, seriesId: 1, sortOrder: 1);

      await db.bookmarkDao.upsertByNaturalKey(entry(page: 1));
      await db.bookmarkDao.upsertByNaturalKey(entry(page: 2));
      await db.bookmarkDao.upsertByNaturalKey(
        bookmark(seriesId: 1, volumeId: 1, chapterId: 2),
      );
      await db.bookmarkDao.upsertByNaturalKey(
        bookmark(seriesId: 1, volumeId: 1, chapterId: 3),
      );

      final list = await db.bookmarkDao.watchBookmarkedChapters().first;
      expect(list.map((c) => c.id), [1, 3, 2]);
    },
  );

  test('watchBookmarkedChapters filters by series and volume', () async {
    await insertSeries(2, 'A');
    await insertVolume(2, 2);
    await insertChapter(id: 2, volumeId: 2, seriesId: 2);

    await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.upsertByNaturalKey(
      bookmark(seriesId: 2, volumeId: 2, chapterId: 2),
    );

    final bySeries = await db.bookmarkDao
        .watchBookmarkedChapters(seriesId: 2)
        .first;
    expect(bySeries.map((c) => c.id), [2]);

    final byVolume = await db.bookmarkDao
        .watchBookmarkedChapters(volumeId: 1)
        .first;
    expect(byVolume.map((c) => c.id), [1]);
  });

  test('watchBookmarkedChapters ignores removed bookmarks', () async {
    final row = await db.bookmarkDao.upsertByNaturalKey(entry());
    await db.bookmarkDao.markRemoved(row.id);

    final list = await db.bookmarkDao.watchBookmarkedChapters().first;
    expect(list, isEmpty);
  });
}
