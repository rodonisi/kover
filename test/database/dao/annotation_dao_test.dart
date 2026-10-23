import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  AnnotationsCompanion annotation({
    required int id,
    int seriesId = 1,
    int chapterId = 1,
    int slot = 0,
  }) {
    return AnnotationsCompanion.insert(
      id: Value(id),
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

  HighlightSlotsCompanion slot(int index, int color) {
    return HighlightSlotsCompanion.insert(
      slotIndex: Value(index),
      color: color,
    );
  }

  group('replaceChapterAnnotations', () {
    test('replaces only the annotations of the given chapter', () async {
      final dao = db.annotationDao;
      await dao.replaceChapterAnnotations(
        chapterId: 1,
        entries: [annotation(id: 1), annotation(id: 2)],
      );
      await dao.replaceChapterAnnotations(
        chapterId: 2,
        entries: [annotation(id: 3, chapterId: 2)],
      );

      await dao.replaceChapterAnnotations(
        chapterId: 1,
        entries: [annotation(id: 2, slot: 3)],
      );

      final stored = await dao.watchSeriesAnnotations(seriesId: 1).first;
      expect(stored.map((a) => a.id), unorderedEquals([2, 3]));
      expect(stored.firstWhere((a) => a.id == 2).selectedSlotIndex, 3);
    });

    test('clears the chapter when no entries are given', () async {
      final dao = db.annotationDao;
      await dao.replaceChapterAnnotations(
        chapterId: 1,
        entries: [annotation(id: 1)],
      );

      await dao.replaceChapterAnnotations(chapterId: 1, entries: []);

      expect(await dao.watchSeriesAnnotations(seriesId: 1).first, isEmpty);
    });
  });

  test('watchSeriesAnnotations only emits annotations of the series', () async {
    final dao = db.annotationDao;
    await dao.replaceChapterAnnotations(
      chapterId: 1,
      entries: [annotation(id: 1), annotation(id: 2, seriesId: 2)],
    );

    final stored = await dao.watchSeriesAnnotations(seriesId: 2).first;
    expect(stored.map((a) => a.id), [2]);
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
