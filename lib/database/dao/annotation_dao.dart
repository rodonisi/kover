import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/annotations.dart';

part 'annotation_dao.g.dart';

@DriftAccessor(tables: [Annotations, HighlightSlots])
class AnnotationDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationDaoMixin {
  AnnotationDao(super.attachedDatabase);

  /// Watch all annotations of [seriesId].
  Stream<List<AnnotationData>> watchSeriesAnnotations({
    required int seriesId,
  }) {
    return (select(
      annotations,
    )..where((row) => row.seriesId.equals(seriesId))).watch();
  }

  /// Replace all stored annotations of [chapterId] with [entries].
  Future<void> replaceChapterAnnotations({
    required int chapterId,
    required Iterable<AnnotationsCompanion> entries,
  }) async {
    await transaction(() async {
      await (delete(
        annotations,
      )..where((row) => row.chapterId.equals(chapterId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(annotations, entries));
    });
  }

  /// Watch the highlight slots, ordered by slot index.
  Stream<List<HighlightSlotData>> watchHighlightSlots() {
    return (select(
      highlightSlots,
    )..orderBy([(t) => OrderingTerm.asc(t.slotIndex)])).watch();
  }

  /// Replace all stored highlight slots with [entries].
  Future<void> replaceHighlightSlots(
    Iterable<HighlightSlotsCompanion> entries,
  ) async {
    await transaction(() async {
      await delete(highlightSlots).go();
      await batch((b) => b.insertAll(highlightSlots, entries));
    });
  }
}
