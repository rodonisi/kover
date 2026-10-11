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
            format: Format.image,
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
      imageOffset: const Value(-1),
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
            format: Format.image,
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

  test('upsert does not duplicate the same natural key', () async {
    await db.bookmarkDao.upsert(entry());
    await db.bookmarkDao.upsert(entry());
    final all = await db.select(db.bookmarks).get();
    expect(all, hasLength(1));
  });

  test('upsert updates an existing tombstone', () async {
    final row = await db.bookmarkDao.upsert(entry());
    await db.bookmarkDao.markRemoved(row.id);
    await db.bookmarkDao.upsert(
      entry().copyWith(dirty: const Value(true), removed: const Value(false)),
    );
    final all = await db.select(db.bookmarks).get();
    expect(all, hasLength(1));
    expect(all.single.removed, isFalse);
    expect(all.single.dirty, isTrue);
  });

  test('markRemoved sets dirty and removed', () async {
    final row = await db.bookmarkDao.upsert(entry());
    await db.bookmarkDao.markRemoved(row.id);
    final stored = await db.bookmarkDao.getBookmark(
      chapterId: 1,
      page: 0,
      xPath: '',
      imageOffset: -1,
    );
    expect(stored!.removed, isTrue);
    expect(stored.dirty, isTrue);
  });

  test('watchBookmarks hides removed rows', () async {
    final row = await db.bookmarkDao.upsert(entry(page: 1));
    await db.bookmarkDao.upsert(entry(page: 2));
    await db.bookmarkDao.markRemoved(row.id);
    final list = await db.bookmarkDao.watchBookmarks(chapterId: 1).first;
    expect(list.map((b) => b.page), [2]);
  });

  test('getDirtyBookmarks returns dirty rows only', () async {
    await db.bookmarkDao.upsert(
      entry(page: 1).copyWith(dirty: const Value(true)),
    );
    await db.bookmarkDao.upsert(entry(page: 2));
    final dirty = await db.bookmarkDao.getDirtyBookmarks();
    expect(dirty.map((b) => b.page), [1]);
  });

  test(
    'watchBookmarks orders by chapter sort order then page',
    () async {
      await insertChapter(id: 2, volumeId: 1, seriesId: 1, sortOrder: 2);
      await insertChapter(id: 3, volumeId: 1, seriesId: 1, sortOrder: 1);

      await db.bookmarkDao.upsert(entry(page: 1));
      await db.bookmarkDao.upsert(
        bookmark(seriesId: 1, volumeId: 1, chapterId: 2),
      );
      await db.bookmarkDao.upsert(
        bookmark(seriesId: 1, volumeId: 1, chapterId: 3),
      );

      final list = await db.bookmarkDao.watchBookmarks(seriesId: 1).first;
      expect(list.map((b) => b.chapterId), [1, 3, 2]);
    },
  );

  test('watchBookmarks filters by series, volume and chapter', () async {
    await insertSeries(2, 'A');
    await insertVolume(2, 2);
    await insertChapter(id: 2, volumeId: 2, seriesId: 2);

    await db.bookmarkDao.upsert(entry());
    await db.bookmarkDao.upsert(
      bookmark(seriesId: 2, volumeId: 2, chapterId: 2),
    );

    final bySeries = await db.bookmarkDao.watchBookmarks(seriesId: 2).first;
    expect(bySeries.map((b) => b.chapterId), [2]);

    final byVolume = await db.bookmarkDao.watchBookmarks(volumeId: 1).first;
    expect(byVolume.map((b) => b.chapterId), [1]);

    final byChapter = await db.bookmarkDao.watchBookmarks(chapterId: 2).first;
    expect(byChapter.map((b) => b.chapterId), [2]);
  });

  test('watchBookmarks ignores removed bookmarks', () async {
    final row = await db.bookmarkDao.upsert(entry());
    await db.bookmarkDao.markRemoved(row.id);

    final list = await db.bookmarkDao.watchBookmarks(seriesId: 1).first;
    expect(list, isEmpty);
  });
}
