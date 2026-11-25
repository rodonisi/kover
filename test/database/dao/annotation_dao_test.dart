import 'package:drift/drift.dart' hide isNull;
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

  AnnotationsCompanion entry({
    int? serverId,
    int chapterId = 1,
    int ownerUserId = 1,
    String xPath = '/p[1]',
    bool dirty = false,
    bool removed = false,
  }) {
    return AnnotationsCompanion.insert(
      serverId: Value.absentIfNull(serverId),
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      libraryId: 1,
      ownerUserId: ownerUserId,
      xPath: Value(xPath),
      selectedText: const Value('text'),
      pageNumber: 1,
      selectedSlotIndex: 0,
      likes: const Value([]),
      dirty: Value(dirty),
      removed: Value(removed),
    );
  }

  test('upsert matches by server id', () async {
    final first = await db.annotationDao.upsert(entry(serverId: 7));
    final second = await db.annotationDao.upsert(
      entry(serverId: 7, xPath: '/p[2]'),
    );

    expect(second.id, first.id);
    expect(second.xPath, '/p[2]');
    expect(await db.select(db.annotations).get(), hasLength(1));
  });

  test('upsert keeps multiple unsynced rows', () async {
    await db.annotationDao.upsert(entry());
    await db.annotationDao.upsert(entry());

    expect(await db.select(db.annotations).get(), hasLength(2));
  });

  test('markRemoved sets dirty and removed', () async {
    final row = await db.annotationDao.upsert(entry(serverId: 7));

    await db.annotationDao.markRemoved(row.id);

    final stored = await db.annotationDao.getAnnotation(row.id);
    expect(stored!.removed, isTrue);
    expect(stored.dirty, isTrue);
    expect((await db.annotationDao.getDirtyAnnotations()).single.id, row.id);
  });

  test('chapter query hides removed rows', () async {
    final removed = await db.annotationDao.upsert(entry(serverId: 1));
    await db.annotationDao.upsert(entry(serverId: 2, xPath: '/p[2]'));
    await db.annotationDao.markRemoved(removed.id);

    final rows = await db.annotationDao.getAnnotationsForChapter(1);

    expect(rows.map((row) => row.serverId), [2]);
  });

  test('getAnnotations hides removed rows', () async {
    final removed = await db.annotationDao.upsert(entry(serverId: 1));
    await db.annotationDao.upsert(entry(serverId: 2, xPath: '/p[2]'));
    await db.annotationDao.markRemoved(removed.id);

    final rows = await db.annotationDao.getAnnotations();

    expect(rows.map((row) => row.serverId), [2]);
  });

  test('deleteByIds removes rows', () async {
    final row = await db.annotationDao.upsert(entry());

    await db.annotationDao.deleteByIds([row.id]);

    expect(await db.annotationDao.getAnnotation(row.id), isNull);
  });

  test('upsert inserts when provided local id no longer exists', () async {
    final inserted = await db.annotationDao.upsert(
      entry(serverId: 7).copyWith(id: const Value(999)),
    );

    expect(inserted.serverId, 7);
    expect(await db.select(db.annotations).get(), hasLength(1));
  });

  test(
    'upsert updates row matched by server id when local id is missing',
    () async {
      final first = await db.annotationDao.upsert(entry(serverId: 7));
      final updated = await db.annotationDao.upsert(
        entry(serverId: 7, xPath: '/p[3]').copyWith(id: const Value(999)),
      );

      expect(updated.id, first.id);
      expect(updated.xPath, '/p[3]');
      expect(await db.select(db.annotations).get(), hasLength(1));
    },
  );
}
