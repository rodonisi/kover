import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart' as api;
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/mapping/dto/highlight_slot_dto_mappings.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
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
    String? ownerUsername,
    required String xPath,
    required String endingXPath,
    required String selectedText,
    required String comment,
    String? commentHtml,
    String? context,
    int highlightCount = 1,
    bool containsSpoiler = false,
    required int pageNumber,
    int selectedSlotIndex = 0,
  }) async {
    final now = DateTime.now();
    final stored = await _db.annotationDao.upsert(
      .insert(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
        libraryId: libraryId,
        ownerUserId: ownerUserId,
        ownerUsername: Value(ownerUsername),
        xPath: xPath,
        endingXPath: endingXPath,
        selectedText: selectedText,
        comment: Value(comment),
        commentHtml: Value(commentHtml),
        context: Value(context),
        highlightCount: Value(highlightCount),
        containsSpoiler: Value(containsSpoiler),
        pageNumber: pageNumber,
        selectedSlotIndex: selectedSlotIndex,
        likes: const Value([]),
        created: now,
        lastModified: now,
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
      },
    );

    await _tryPush(stored);
  }

  /// Updates the modifiable fields of the annotation with [id] if owned by
  /// [ownerUserId]. The annotation is marked as dirty and a request is sent to
  /// the server. If the request fails, the annotation remains dirty and will be
  /// retried on the next sync.
  Future<void> updateAnnotation({
    required int id,
    required int ownerUserId,
    required String comment,
    required String? commentHtml,
    required bool containsSpoiler,
    required int selectedSlotIndex,
  }) async {
    final existing = await _db.annotationDao.getAnnotation(id);
    if (existing == null ||
        existing.removed ||
        existing.ownerUserId != ownerUserId) {
      return;
    }

    final updated = await _db.annotationDao.upsert(
      AnnotationsCompanion(
        id: Value(id),
        comment: Value(comment),
        commentHtml: Value(commentHtml),
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

  /// Removes the annotation with [id] if owned by [ownerUserId]. The annotation
  /// is marked as removed and a request is sent to the server to remove it. If
  /// the server request fails, the annotation remains marked as removed and
  /// will be retried on the next sync.
  Future<void> removeAnnotation(int id, {required int ownerUserId}) async {
    final removed = await _db.annotationDao.markRemoved(
      id,
      ownerUserId: ownerUserId,
    );
    if (removed == null) return;

    log.debug(
      'removing annotation',
      attributes: {'id': id, 'server_id': removed.serverId},
    );

    await _tryPush(removed);
  }

  /// Refreshes the user's highlight slots during annotation sync.
  Future<void> refreshHighlightSlots() async {
    try {
      final user = await _client.getCurrentUser();
      final slots = user.preferences?.bookReaderHighlightSlots;
      if (slots != null) await replaceHighlightSlots(slots);
    } catch (error) {
      log.warning(
        'could not refresh highlight slots',
        attributes: {'error': error},
      );
    }
  }

  /// Merges all dirty annotations with the server.
  Future<void> mergeAnnotations() async {
    final dirty = await _db.annotationDao.getDirtyAnnotations();
    if (dirty.isEmpty) return;

    for (final annotation in dirty) {
      try {
        await _push(annotation);
      } catch (e, stacktrace) {
        log.error(
          'could not merge annotation',
          error: e,
          stacktrace: stacktrace,
        );
      }
    }
  }

  /// Fetches all annotations from the server and merges them with the local
  /// database. This is a full refresh that ensures the local state matches the
  /// server state. It deletes clean local annotations that are not present on
  /// the server.
  Future<void> refreshAllAnnotations() async {
    final remote = await _client.getAllAnnotations();
    await _reconcileRemote(remote);
  }

  /// Fetches the annotations for [chapterId] from the server and merges them
  /// with the local database. Clean local annotations for the chapter that are
  /// not present on the server are deleted.
  Future<void> refreshChapterAnnotations({required int chapterId}) async {
    final remote = await _client.getChapterAnnotations(chapterId);
    await _reconcileRemote(remote, chapterId: chapterId);
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

  /// Push a local annotation once. Failures leave the row dirty for retry.
  Future<void> _push(Annotation annotation) async {
    if (annotation.removed) {
      if (annotation.serverId case final serverId?) {
        await _client.remove(serverId);
      }
      await _db.annotationDao.deleteByIds([annotation.id]);
      return;
    }

    final remote = annotation.serverId == null
        ? await _client.create(annotation.toAnnotationDto())
        : await _client.update(annotation.toAnnotationDto());
    final companion = remote.toAnnotationCompanion(localId: annotation.id);
    if (companion == null) {
      throw StateError(
        'Server returned an invalid annotation for local id ${annotation.id}',
      );
    }
    await _db.annotationDao.upsert(companion);
  }

  Future<void> _reconcileRemote(
    Iterable<api.AnnotationDto> remote, {
    int? chapterId,
  }) async {
    final validEntries = remote
        .map((dto) => dto.toAnnotationCompanion())
        .whereType<AnnotationsCompanion>()
        .toList();
    final existingChapterIds = await _db.chaptersDao.getExistingChapterIds();
    final entries = validEntries
        .where((entry) => existingChapterIds.contains(entry.chapterId.value))
        .toList();

    await _db.annotationDao.mergeRemoteBatch(entries);

    final remoteIds = validEntries
        .map((entry) => entry.serverId.value)
        .whereType<int>()
        .toSet();
    await _db.annotationDao.deleteStaleAnnotations(
      remoteIds,
      chapterId: chapterId,
    );
  }

  /// Watch the locally stored annotation with local [id].
  Stream<AnnotationModel?> watchAnnotation({required int id}) {
    return _db.annotationDao
        .watchAnnotation(id)
        .map(
          (annotation) => annotation == null
              ? null
              : AnnotationModel.fromDatabaseModel(annotation),
        );
  }

  /// Watch all locally stored, non-removed annotations for [chapterId].
  Stream<List<AnnotationModel>> watchAnnotations({required int chapterId}) {
    return _db.annotationDao
        .watchAnnotationsForChapter(chapterId)
        .map(
          (annotations) => annotations
              .map(AnnotationModel.fromDatabaseModel)
              .toList(growable: false),
        );
  }

  /// Watch all locally stored highlight slots, ordered by slot number.
  Stream<List<HighlightSlotModel>> watchHighlightSlots() {
    return _db.annotationDao.watchHighlightSlots().map(
      (slots) => slots
          .map(HighlightSlotModel.fromDatabaseModel)
          .toList(growable: false),
    );
  }

  /// Replace all locally stored highlight slots with [slots].
  Future<void> replaceHighlightSlots(Iterable<api.HighlightSlot> slots) {
    final companions = slots
        .map((slot) => slot.toHighlightSlotCompanion())
        .whereType<HighlightSlotsCompanion>();
    return _db.annotationDao.replaceHighlightSlots(companions);
  }
}
