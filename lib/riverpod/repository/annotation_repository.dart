import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'annotation_repository.g.dart';

@Riverpod(keepAlive: true)
AnnotationRepository annotationRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(restClientProvider);
  return AnnotationRepository(db, AnnotationSyncOperations(client));
}

class AnnotationRepository(
  final AppDatabase _db,
  final AnnotationSyncOperations _client,
) {
  /// Adds an annotation. The annotation is marked as dirty and a request is
  /// sent to the server to create it. If the server request fails, the
  /// annotation remains dirty and will be retried on the next sync.
  Future<void> addAnnotation({
    required int seriesId,
    required int volumeId,
    required int chapterId,
    required int libraryId,
    required int ownerUserId,
    String? xPath,
    String? endingXPath,
    required String selectedText,
    String? comment,
    String? commentHtml,
    String? commentPlainText,
    String? context,
    int highlightCount = 1,
    bool containsSpoiler = false,
    int? pageNumber,
    int selectedSlotIndex = 0,
  }) async {
    final now = DateTime.now();
    final stored = await _db.annotationDao.upsert(
      AnnotationsCompanion(
        seriesId: Value(seriesId),
        volumeId: Value(volumeId),
        chapterId: Value(chapterId),
        libraryId: Value(libraryId),
        ownerUserId: Value(ownerUserId),
        xPath: Value(xPath),
        endingXPath: Value(endingXPath),
        selectedText: Value(selectedText),
        comment: Value(comment),
        commentHtml: Value(commentHtml),
        commentPlainText: Value(commentPlainText),
        context: Value(context),
        highlightCount: Value(highlightCount),
        containsSpoiler: Value(containsSpoiler),
        pageNumber: Value(pageNumber),
        selectedSlotIndex: Value(selectedSlotIndex),
        likes: const Value([]),
        created: Value(now),
        lastModified: Value(now),
        dirty: const Value(true),
        removed: const Value(false),
      ),
    );

    log.debug(
      'adding annotation',
      attributes: {
        'series_id': seriesId,
        'volume_id': volumeId,
        'chapter_id': chapterId,
        'library_id': libraryId,
        'xpath': xPath,
        'stored': stored,
      },
    );

    await _tryPush(stored);
  }

  /// Updates the modifiable fields of the annotation with [id]. The annotation
  /// is marked as dirty and a request is sent to the server. If the request
  /// fails, the annotation remains dirty and will be retried on the next sync.
  Future<void> updateAnnotation({
    required int id,
    required String? comment,
    required String? commentHtml,
    required String? commentPlainText,
    required bool containsSpoiler,
    required int selectedSlotIndex,
  }) async {
    final existing = await _db.annotationDao.getAnnotation(id);
    if (existing == null || existing.removed) return;

    final updated = await _db.annotationDao.upsert(
      AnnotationsCompanion(
        id: Value(id),
        comment: Value(comment),
        commentHtml: Value(commentHtml),
        commentPlainText: Value(commentPlainText),
        containsSpoiler: Value(containsSpoiler),
        selectedSlotIndex: Value(selectedSlotIndex),
        lastModified: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    log.debug(
      'updating annotation',
      attributes: {'id': id, 'server_id': updated.serverId},
    );

    await _tryPush(updated);
  }

  /// Removes the annotation with [id]. If the annotation has never been
  /// successfully pushed to the server, it is hard-deleted. If it has been
  /// pushed, it is marked as removed and a request is sent to the server to
  /// remove it. If the server request fails, the annotation remains marked as
  /// removed and will be retried on the next sync.
  Future<void> removeAnnotation(int id) async {
    final stored = await _db.annotationDao.getAnnotation(id);
    if (stored == null || stored.removed) return;

    log.debug(
      'removing annotation',
      attributes: {'id': id, 'server_id': stored.serverId},
    );

    final serverId = stored.serverId;
    if (serverId == null) {
      // Never successfully pushed, or an orphaned clean row: no remote copy
      // exists, so it is safe to hard-delete.
      await _db.annotationDao.deleteByIds([stored.id]);
      return;
    }

    await _db.annotationDao.markRemoved(stored.id);
    try {
      await _client.remove(serverId);
      await _db.annotationDao.deleteByIds([stored.id]);
    } catch (e) {
      log.info('could not remove annotation', attributes: {'error': e});
    }
  }

  /// Merges all dirty annotations with the server. Dirty annotations are those
  /// that have been added, updated, or removed locally but not yet successfully
  /// pushed to the server. If a dirty annotation is successfully pushed, its
  /// dirty flag is cleared. Removed annotations are hard-deleted locally once
  /// the server confirms the deletion.
  Future<void> mergeAnnotations() async {
    final dirty = await _db.annotationDao.getDirtyAnnotations();
    if (dirty.isEmpty) return;

    final removed = <int>[];
    for (final annotation in dirty) {
      try {
        if (annotation.removed) {
          if (annotation.serverId != null) {
            await _client.remove(annotation.serverId!);
          }
          removed.add(annotation.id);
          continue;
        }

        await _push(annotation);
      } catch (e, stacktrace) {
        log.error(
          'could not merge annotation',
          error: e,
          stacktrace: stacktrace,
        );
      }
    }

    if (removed.isNotEmpty) await _db.annotationDao.deleteByIds(removed);
  }

  /// Fetches all annotations from the server and merges them with the local
  /// database. This is a full refresh that ensures the local state matches the
  /// server state. It deletes clean local annotations that are not present on
  /// the server.
  Future<void> refreshAllAnnotations() async {
    final remote = await _client.getAllAnnotations();
    await _mergeRemote(remote);
    await _deleteMissingRemote(remote);
  }

  /// Fetches the annotations for [chapterId] from the server and merges them
  /// with the local database. Clean local annotations for the chapter that are
  /// not present on the server are deleted.
  Future<void> refreshChapterAnnotations({required int chapterId}) async {
    final remote = await _client.getChapterAnnotations(chapterId);
    await _mergeRemote(remote);
    await _deleteMissingRemote(remote, chapterId: chapterId);
  }

  /// Push a local annotation and keep the row dirty if the request fails.
  Future<void> _tryPush(Annotation annotation) async {
    try {
      await _push(annotation);
    } catch (e) {
      log.info(
        'could not push annotation',
        attributes: {'id': annotation.id, 'error': e},
      );
    }
  }

  /// Push a local annotation to the server and merge the server representation
  /// back into the local row.
  Future<void> _push(Annotation annotation) async {
    final dto = annotation.toAnnotationDto();
    final remote = annotation.serverId == null
        ? await _client.create(dto)
        : await _client.update(dto);
    await _db.annotationDao.upsert(
      remote.toAnnotationCompanion(localId: annotation.id),
    );
  }

  /// Deletes local rows that are clean and whose server id is absent from
  /// [remote]. Dirty rows are never deleted: they hold unsynced local intent.
  Future<void> _deleteMissingRemote(
    Iterable<AnnotationDto> remote, {
    int? chapterId,
  }) async {
    final remoteIds = remote.map((dto) => dto.id).whereType<int>().toSet();

    final local = chapterId == null
        ? await _db.annotationDao.getAnnotations()
        : await _db.annotationDao.getAnnotationsForChapter(chapterId);

    final stale = local
        .where(
          (a) =>
              !a.dirty && a.serverId != null && !remoteIds.contains(a.serverId),
        )
        .map((a) => a.id)
        .toList();

    if (stale.isNotEmpty) {
      await _db.annotationDao.deleteByIds(stale);
    }
  }

  Future<void> _mergeRemote(Iterable<AnnotationDto> remote) async {
    final existingChapterIds = (await _db.annotationDao.getExistingChapterIds())
        .toSet();

    for (final dto in remote) {
      final serverId = dto.id;
      if (serverId == null) {
        log.warning('skipping annotation without server id');
        continue;
      }
      if (!existingChapterIds.contains(dto.chapterId)) {
        log.warning(
          'skipping annotation for unknown chapter',
          attributes: {'chapter_id': dto.chapterId, 'annotation_id': serverId},
        );
        continue;
      }

      final local = await _db.annotationDao.getAnnotationByServerId(serverId);
      if (local != null && local.dirty) {
        log.warning(
          'skipping remote annotation for dirty local row',
          attributes: {'annotation_id': serverId},
        );
        continue;
      }

      await _db.annotationDao.upsert(
        dto.toAnnotationCompanion(localId: local?.id),
      );
    }
  }
}
