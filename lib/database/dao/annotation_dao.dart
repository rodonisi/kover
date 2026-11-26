import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/annotations.dart';
import 'package:kover/database/tables/highlight_slots.dart';

part 'annotation_dao.g.dart';

@DriftAccessor(tables: [Annotations, HighlightSlots])
class AnnotationDao(super.attachedDatabase)
    extends DatabaseAccessor<AppDatabase>
    with _$AnnotationDaoMixin {
  /// Get every locally stored annotation row that has been modified since the
  /// last sync.
  Future<List<Annotation>> getDirtyAnnotations() {
    return (select(annotations)..where((a) => a.dirty.equals(true))).get();
  }

  /// Get the annotation with local [id].
  Future<Annotation?> getAnnotation(int id) {
    return (select(
      annotations,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Watch the annotation with local [id].
  ///
  /// Removed rows are included so the sheet stays populated while deletion is
  /// still in flight. The row disappears once the server confirms removal.
  Stream<Annotation?> watchAnnotation(int id) {
    return (select(
      annotations,
    )..where((a) => a.id.equals(id))).watchSingleOrNull();
  }

  /// Get the annotation with the remote [serverId].
  Future<Annotation?> getAnnotationByServerId(int serverId) {
    return (select(
      annotations,
    )..where((a) => a.serverId.equals(serverId))).getSingleOrNull();
  }

  /// Every locally stored, non-removed annotation row, dirty and clean alike.
  Future<List<Annotation>> getAnnotations() {
    return (select(
      annotations,
    )..where((a) => a.removed.equals(false))).get();
  }

  /// Every locally stored, non-removed annotation row for [chapterId].
  Future<List<Annotation>> getAnnotationsForChapter(int chapterId) {
    return (select(annotations)..where(
          (a) => a.chapterId.equals(chapterId) & a.removed.equals(false),
        ))
        .get();
  }

  /// Watch every locally stored, non-removed annotation row for [chapterId].
  Stream<List<Annotation>> watchAnnotationsForChapter(int chapterId) {
    return (select(annotations)
          ..where(
            (a) => a.chapterId.equals(chapterId) & a.removed.equals(false),
          )
          ..orderBy([
            (a) => OrderingTerm.asc(a.pageNumber),
            (a) => OrderingTerm.asc(a.id),
          ]))
        .watch();
  }

  /// Watch all locally stored highlight slots, ordered by slot number.
  Stream<List<HighlightSlot>> watchHighlightSlots() {
    return (select(
      highlightSlots,
    )..orderBy([(s) => OrderingTerm.asc(s.slotNumber)])).watch();
  }

  /// Replace all locally stored highlight slots with [slots].
  Future<void> replaceHighlightSlots(Iterable<HighlightSlotsCompanion> slots) {
    return transaction(() async {
      await delete(highlightSlots).go();
      final entries = slots.toList();
      if (entries.isEmpty) return;
      await batch((batch) => batch.insertAll(highlightSlots, entries));
    });
  }

  /// Mark the annotation with [id] as removed if owned by [ownerUserId].
  ///
  /// Returns the updated tombstone, or null if no matching row exists.
  Future<Annotation?> markRemoved(int id, {required int ownerUserId}) async {
    final rows =
        await (update(annotations)..where(
              (a) =>
                  a.id.equals(id) &
                  a.ownerUserId.equals(ownerUserId) &
                  a.removed.equals(false),
            ))
            .writeReturning(
              const AnnotationsCompanion(
                dirty: Value(true),
                removed: Value(true),
              ),
            );
    return rows.singleOrNull;
  }

  /// Delete the annotations with the given [ids] from the local database.
  Future<void> deleteByIds(Iterable<int> ids) async {
    await (delete(annotations)..where((a) => a.id.isIn(ids))).go();
  }

  /// Delete clean annotations whose server ids are absent from [remoteIds].
  ///
  /// Dirty and removed rows are preserved. When [chapterId] is provided, only
  /// annotations in that chapter are considered.
  Future<void> deleteStaleAnnotations(
    Iterable<int> remoteIds, {
    int? chapterId,
  }) async {
    await (delete(annotations)..where(
          (a) =>
              a.dirty.equals(false) &
              a.removed.equals(false) &
              a.serverId.isNotNull() &
              a.serverId.isIn(remoteIds).not() &
              (chapterId == null
                  ? const Constant(true)
                  : a.chapterId.equals(chapterId)),
        ))
        .go();
  }

  /// Merge remote annotation [entries] in one batch.
  ///
  /// Entries matching dirty local rows are skipped.
  Future<void> mergeRemoteBatch(
    Iterable<AnnotationsCompanion> entries,
  ) async {
    final incoming = entries.toList();
    if (incoming.isEmpty) return;

    final serverIds = incoming
        .map((entry) => entry.serverId.present ? entry.serverId.value : null)
        .whereType<int>()
        .toSet();

    await transaction(() async {
      final local = await (select(
        annotations,
      )..where((a) => a.serverId.isIn(serverIds))).get();
      final dirtyServerIds = local
          .where((annotation) => annotation.dirty)
          .map((annotation) => annotation.serverId)
          .whereType<int>()
          .toSet();
      final toUpsert = incoming.where((entry) {
        final serverId = entry.serverId.present ? entry.serverId.value : null;
        return serverId == null || !dirtyServerIds.contains(serverId);
      }).toList();

      if (toUpsert.isNotEmpty) {
        await batch((batch) {
          for (final entry in toUpsert) {
            batch.insert(
              annotations,
              entry,
              onConflict: DoUpdate(
                (_) => entry,
                target: [annotations.serverId],
                where: (_) => annotations.dirty.equals(false),
              ),
            );
          }
        });
      }
    });
  }

  /// Add or update an annotation entry, matching by local id or server id.
  Future<Annotation> upsert(AnnotationsCompanion entry) {
    return transaction(() async {
      Annotation? existing;
      if (entry.id.present) {
        existing = await getAnnotation(entry.id.value);
      }
      if (existing == null &&
          entry.serverId.present &&
          entry.serverId.value != null) {
        existing = await getAnnotationByServerId(entry.serverId.value!);
      }

      final id = existing?.id;
      if (id != null) {
        final rows = await (update(annotations)..where((a) => a.id.equals(id)))
            .writeReturning(entry.copyWith(id: Value(id)));
        return rows.single;
      }

      return into(annotations)
          .insertReturning(entry.copyWith(id: const Value.absent()));
    });
  }
}
