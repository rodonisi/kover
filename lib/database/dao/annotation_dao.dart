import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/annotations.dart';
import 'package:kover/database/tables/chapters.dart';

part 'annotation_dao.g.dart';

@DriftAccessor(tables: [Annotations, HighlightSlots, Chapters])
class AnnotationDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationDaoMixin {
  AnnotationDao(super.attachedDatabase);

  /// Watch all annotations of [seriesId] that are not marked as deleted.
  Stream<List<Annotation>> watchSeriesAnnotations({
    required int seriesId,
  }) {
    return (select(annotations)..where(
          (row) => row.seriesId.equals(seriesId) & row.deleted.equals(false),
        ))
        .watch();
  }

  /// Merge the server annotations [remote] into the stored ones, limited to
  /// [chapterId] when given. Rows with local changes (dirty) are kept as they
  /// are. Other rows are updated from [remote], or deleted when missing from
  /// it. Annotations of chapters that are not stored locally are skipped.
  Future<void> mergeAnnotations(
    Iterable<AnnotationsCompanion> remote, {
    int? chapterId,
  }) async {
    final entries = remote.toList();
    final remoteIds = entries.map((e) => e.serverId.value!).toSet();

    await transaction(() async {
      final knownChapterIds = await _existingChapterIds(
        entries.map((e) => e.chapterId.value),
      );
      final stored = {
        for (final row in await (select(
          annotations,
        )..where((row) => row.serverId.isIn(remoteIds))).get())
          row.serverId!: row,
      };

      await batch((b) {
        for (final entry in entries) {
          final local = stored[entry.serverId.value];
          if (local == null) {
            if (knownChapterIds.contains(entry.chapterId.value)) {
              b.insert(annotations, entry);
            }
          } else if (!local.dirty) {
            b.update(
              annotations,
              entry,
              where: (row) => row.id.equals(local.id),
            );
          }
        }
      });

      final stale = delete(annotations)
        ..where(
          (row) => row.dirty.equals(false) & row.serverId.isNotIn(remoteIds),
        );
      if (chapterId != null) {
        stale.where((row) => row.chapterId.equals(chapterId));
      }
      await stale.go();
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

  Future<Set<int>> _existingChapterIds(Iterable<int> chapterIds) async {
    final q = selectOnly(chapters)
      ..addColumns([chapters.id])
      ..where(chapters.id.isIn(chapterIds));
    return (await q.map((row) => row.read(chapters.id)!).get()).toSet();
  }
}
