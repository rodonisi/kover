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
    for (final (chapterId, seriesId) in [(1, 1), (2, 1), (3, 2)]) {
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: Value(chapterId),
              volumeId: 1,
              seriesId: seriesId,
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
    }
  });

  tearDown(() => db.close());

  AnnotationsCompanion remote({
    required int serverId,
    int chapterId = 1,
    int seriesId = 1,
    int slot = 0,
  }) {
    return AnnotationsCompanion.insert(
      serverId: Value(serverId),
      seriesId: seriesId,
      volumeId: 1,
      chapterId: chapterId,
      page: 0,
      xPath: '//body/p[1]',
      selectedText: 'text',
      selectedSlotIndex: slot,
      ownerUserId: 1,
    );
  }

  Future<void> insertLocal(AnnotationsCompanion entry) =>
      db.into(db.annotations).insert(entry);

  Future<List<Annotation>> stored() => db.select(db.annotations).get();

  HighlightSlotsCompanion slot(int index, int color) {
    return HighlightSlotsCompanion.insert(
      slotIndex: Value(index),
      color: color,
    );
  }

  group('mergeAnnotations', () {
    test('inserts new annotations and updates clean ones', () async {
      final dao = db.annotationDao;
      await dao.mergeAnnotations([remote(serverId: 1), remote(serverId: 2)]);
      final id = (await stored()).firstWhere((a) => a.serverId == 2).id;

      await dao.mergeAnnotations([
        remote(serverId: 1),
        remote(serverId: 2, slot: 3),
      ]);

      final rows = await stored();
      expect(rows.map((a) => a.serverId), unorderedEquals([1, 2]));
      final updated = rows.firstWhere((a) => a.serverId == 2);
      expect(updated.id, id);
      expect(updated.selectedSlotIndex, 3);
    });

    test('skips annotations of unknown chapters', () async {
      await db.annotationDao.mergeAnnotations([
        remote(serverId: 1),
        remote(serverId: 2, chapterId: 99),
      ]);

      expect((await stored()).map((a) => a.serverId), [1]);
    });

    test('keeps rows with local changes', () async {
      await insertLocal(
        remote(serverId: 1, slot: 4).copyWith(dirty: const Value(true)),
      );
      await insertLocal(
        remote(serverId: 2).copyWith(
          dirty: const Value(true),
          deleted: const Value(true),
        ),
      );
      await insertLocal(
        remote(serverId: 3).copyWith(
          serverId: const Value(null),
          dirty: const Value(true),
        ),
      );

      await db.annotationDao.mergeAnnotations([remote(serverId: 1)]);

      final rows = await stored();
      expect(rows, hasLength(3));
      expect(rows.firstWhere((a) => a.serverId == 1).selectedSlotIndex, 4);
    });

    test('deletes clean rows missing from the server', () async {
      final dao = db.annotationDao;
      await dao.mergeAnnotations([
        remote(serverId: 1),
        remote(serverId: 2, chapterId: 2),
        remote(serverId: 3, chapterId: 3, seriesId: 2),
      ]);

      await dao.mergeAnnotations([remote(serverId: 1)]);

      expect((await stored()).map((a) => a.serverId), [1]);
    });

    test('limits deletions to the given chapter', () async {
      final dao = db.annotationDao;
      await dao.mergeAnnotations([
        remote(serverId: 1),
        remote(serverId: 2),
        remote(serverId: 3, chapterId: 2),
      ]);

      await dao.mergeAnnotations([remote(serverId: 2)], chapterId: 1);

      expect(
        (await stored()).map((a) => a.serverId),
        unorderedEquals([2, 3]),
      );
    });
  });

  test('watchSeriesAnnotations skips other series and deleted rows', () async {
    await db.annotationDao.mergeAnnotations([
      remote(serverId: 1),
      remote(serverId: 2),
      remote(serverId: 3, chapterId: 3, seriesId: 2),
    ]);
    await (db.update(
      db.annotations,
    )..where((a) => a.serverId.equals(2))).write(
      const AnnotationsCompanion(dirty: Value(true), deleted: Value(true)),
    );

    final annotations = await db.annotationDao
        .watchSeriesAnnotations(seriesId: 1)
        .first;
    expect(annotations.map((a) => a.serverId), [1]);
  });

  test('replaceHighlightSlots replaces all slots ordered by index', () async {
    final dao = db.annotationDao;
    await dao.replaceHighlightSlots([slot(0, 0xff000000), slot(1, 0xff111111)]);

    await dao.replaceHighlightSlots([slot(1, 0xff222222), slot(0, 0xff333333)]);

    final stored = await dao.watchHighlightSlots().first;
    expect(stored.map((s) => s.slotIndex), [0, 1]);
    expect(stored.map((s) => s.color), [0xff333333, 0xff222222]);
  });
}
