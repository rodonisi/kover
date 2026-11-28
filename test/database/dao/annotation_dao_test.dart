import 'package:drift/drift.dart' hide isNull, isNotNull;
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
    final now = DateTime.utc(2026);
    return AnnotationsCompanion.insert(
      serverId: Value.absentIfNull(serverId),
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      libraryId: 1,
      ownerUserId: ownerUserId,
      xPath: xPath,
      endingXPath: xPath,
      selectedText: 'text',
      pageNumber: 1,
      selectedSlotIndex: 0,
      likes: const Value([]),
      created: now,
      lastModified: now,
      dirty: Value(dirty),
      removed: Value(removed),
    );
  }

  HighlightSlotsCompanion slot(
    int slotNumber, {
    int? red,
    int? green,
    int? blue,
    double? alpha,
  }) {
    return HighlightSlotsCompanion.insert(
      slotNumber: Value(slotNumber),
      red: Value(red),
      green: Value(green),
      blue: Value(blue),
      alpha: Value(alpha),
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

    final removed = await db.annotationDao.markRemoved(
      row.id,
      ownerUserId: 1,
    );

    expect(removed!.id, row.id);
    expect(removed.serverId, 7);
    expect(removed.removed, isTrue);
    expect(removed.dirty, isTrue);
    final stored = await db.annotationDao.getAnnotation(row.id);
    expect(stored!.removed, isTrue);
    expect(stored.dirty, isTrue);
    expect((await db.annotationDao.getDirtyAnnotations()).single.id, row.id);
  });

  test('markRemoved returns null for another owner', () async {
    final row = await db.annotationDao.upsert(entry(serverId: 7));

    final removed = await db.annotationDao.markRemoved(
      row.id,
      ownerUserId: 2,
    );

    expect(removed, isNull);
    final stored = await db.annotationDao.getAnnotation(row.id);
    expect(stored!.removed, isFalse);
    expect(stored.dirty, isFalse);
  });

  test('markRemoved returns null for missing or removed rows', () async {
    expect(
      await db.annotationDao.markRemoved(999, ownerUserId: 1),
      isNull,
    );

    final row = await db.annotationDao.upsert(entry(serverId: 7));
    await db.annotationDao.markRemoved(row.id, ownerUserId: 1);

    expect(
      await db.annotationDao.markRemoved(row.id, ownerUserId: 1),
      isNull,
    );
  });

  test('chapter query hides removed rows', () async {
    final removed = await db.annotationDao.upsert(entry(serverId: 1));
    await db.annotationDao.upsert(entry(serverId: 2, xPath: '/p[2]'));
    await db.annotationDao.markRemoved(removed.id, ownerUserId: 1);

    final rows = await db.annotationDao.getAnnotationsForChapter(1);

    expect(rows.map((row) => row.serverId), [2]);
  });

  test('getAnnotations hides removed rows', () async {
    final removed = await db.annotationDao.upsert(entry(serverId: 1));
    await db.annotationDao.upsert(entry(serverId: 2, xPath: '/p[2]'));
    await db.annotationDao.markRemoved(removed.id, ownerUserId: 1);

    final rows = await db.annotationDao.getAnnotations();

    expect(rows.map((row) => row.serverId), [2]);
  });

  test('watchAnnotation emits the row and its tombstone', () async {
    final row = await db.annotationDao.upsert(entry(serverId: 1));
    final stream = db.annotationDao.watchAnnotation(row.id);

    expect((await stream.first)?.id, row.id);

    await db.annotationDao.markRemoved(row.id, ownerUserId: 1);
    expect((await stream.first)?.removed, isTrue);

    await db.annotationDao.deleteByIds([row.id]);
    expect(await stream.first, isNull);
  });

  test('deleteByIds removes dirty rows', () async {
    final row = await db.annotationDao.upsert(entry(dirty: true));

    await db.annotationDao.deleteByIds([row.id]);

    expect(await db.annotationDao.getAnnotation(row.id), isNull);
  });

  test(
    'deleteStaleAnnotations deletes only clean rows absent remotely',
    () async {
      final stale = await db.annotationDao.upsert(entry(serverId: 1));
      final remote = await db.annotationDao.upsert(entry(serverId: 2));
      final dirty = await db.annotationDao.upsert(
        entry(serverId: 3, dirty: true),
      );
      final unsynced = await db.annotationDao.upsert(entry());
      final removed = await db.annotationDao.upsert(
        entry(serverId: 4, removed: true),
      );

      await db.annotationDao.deleteStaleAnnotations([2]);

      final rows = await db.select(db.annotations).get();
      expect(
        rows.map((row) => row.id),
        unorderedEquals([remote.id, dirty.id, unsynced.id, removed.id]),
      );
      expect(await db.annotationDao.getAnnotation(stale.id), isNull);
    },
  );

  test('deleteStaleAnnotations scopes deletion to the chapter', () async {
    final stale = await db.annotationDao.upsert(entry(serverId: 1));

    await db.annotationDao.deleteStaleAnnotations([], chapterId: 99);
    expect(await db.annotationDao.getAnnotation(stale.id), isNotNull);

    await db.annotationDao.deleteStaleAnnotations([]);
    expect(await db.annotationDao.getAnnotation(stale.id), isNull);
  });

  test('mergeRemoteBatch preserves dirty rows and merges the rest', () async {
    final clean = await db.annotationDao.upsert(
      entry(serverId: 7, xPath: '/p[1]'),
    );
    await db.annotationDao.upsert(
      entry(serverId: 8, xPath: '/local', dirty: true),
    );

    await db.annotationDao.mergeRemoteBatch([
      entry(serverId: 7, xPath: '/p[2]'),
      entry(serverId: 8, xPath: '/remote'),
      entry(serverId: 9, xPath: '/p[3]'),
    ]);

    final updated = await db.annotationDao.getAnnotationByServerId(7);
    expect(updated!.id, clean.id);
    expect(updated.xPath, '/p[2]');
    expect(updated.dirty, isFalse);
    final preserved = await db.annotationDao.getAnnotationByServerId(8);
    expect(preserved!.xPath, '/local');
    expect(preserved.dirty, isTrue);
    expect((await db.annotationDao.getAnnotationByServerId(9))!.xPath, '/p[3]');
    expect(await db.select(db.annotations).get(), hasLength(3));
  });

  test(
    'replaceHighlightSlots stores all slots ordered by slot number',
    () async {
      await db.annotationDao.replaceHighlightSlots([
        slot(2, red: 0, green: 255, blue: 0, alpha: 0.5),
        slot(0, red: 255, green: 0, blue: 0, alpha: 1),
      ]);

      final slots = await db.annotationDao.watchHighlightSlots().first;

      expect(slots.map((slot) => slot.slotNumber), [0, 2]);
      expect(slots.first.red, 255);
      expect(slots.first.green, 0);
      expect(slots.first.blue, 0);
      expect(slots.first.alpha, 1);
      expect(slots.last.alpha, 0.5);
    },
  );

  test(
    'replaceHighlightSlots removes slots that are no longer present',
    () async {
      await db.annotationDao.replaceHighlightSlots([slot(0), slot(1)]);

      await db.annotationDao.replaceHighlightSlots([slot(2)]);

      final slots = await db.annotationDao.watchHighlightSlots().first;
      expect(slots.map((slot) => slot.slotNumber), [2]);
    },
  );

  test('replaceHighlightSlots with an empty list clears all slots', () async {
    await db.annotationDao.replaceHighlightSlots([slot(0)]);

    await db.annotationDao.replaceHighlightSlots(const []);

    expect(await db.annotationDao.watchHighlightSlots().first, isEmpty);
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
