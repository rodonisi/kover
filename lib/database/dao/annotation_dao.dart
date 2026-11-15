import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/annotations.dart';
import 'package:kover/database/tables/chapters.dart';

part 'annotation_dao.g.dart';

@DriftAccessor(tables: [Annotations, Chapters])
class AnnotationDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationDaoMixin {
  AnnotationDao(super.attachedDatabase);

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

  /// Get the annotation with the remote [serverId].
  Future<Annotation?> getAnnotationByServerId(int serverId) {
    return (select(
      annotations,
    )..where((a) => a.serverId.equals(serverId))).getSingleOrNull();
  }

  /// Every locally stored, non-removed annotation row, dirty and clean alike.
  /// Used to reconcile against the remote set during a full refresh.
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

  /// Get the IDs of all chapters that are known locally.
  Future<List<int>> getExistingChapterIds() async {
    final q = selectOnly(chapters, distinct: true)..addColumns([chapters.id]);
    return q.map((row) => row.read(chapters.id)!).get();
  }

  /// Mark the annotation with [id] as removed.
  Future<void> markRemoved(int id) {
    return (update(annotations)..where((a) => a.id.equals(id))).write(
      const AnnotationsCompanion(dirty: Value(true), removed: Value(true)),
    );
  }

  /// Delete the annotations with the given [ids] from the local database.
  Future<void> deleteByIds(Iterable<int> ids) async {
    await (delete(annotations)..where((a) => a.id.isIn(ids))).go();
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

      final id = entry.id.present ? entry.id.value : existing?.id;
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
