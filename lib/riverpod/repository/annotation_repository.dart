import 'package:drift/drift.dart' show Value;
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/quill_note.dart';
import 'package:material_ui/material_ui.dart';
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
  /// Watch all stored annotations of [seriesId].
  Stream<List<AnnotationModel>> watchSeriesAnnotations({
    required int seriesId,
  }) => _db.annotationDao
      .watchSeriesAnnotations(seriesId: seriesId)
      .map((l) => l.map(AnnotationModel.fromDatabaseModel).toList());

  /// Watch the user's highlight colors, ordered by slot index.
  Stream<List<Color>> watchHighlightSlots() => _db.annotationDao
      .watchHighlightSlots()
      .map((l) => l.map((slot) => Color(slot.color)).toList());

  /// Fetch all annotations visible to the user and merge them with the stored
  /// ones. Annotations with local changes are kept.
  Future<void> refreshAllAnnotations() async {
    final entries = _toCompanions(await _client.getAllAnnotations());
    await _db.annotationDao.mergeAnnotations(entries);

    log.debug(
      'refreshed all annotations',
      attributes: {'count': entries.length},
    );
  }

  /// Fetch the annotations of [chapterId] from the server and merge them with
  /// the stored ones. Annotations with local changes are kept.
  Future<void> refreshChapterAnnotations({required int chapterId}) async {
    final entries = _toCompanions(
      await _client.getChapterAnnotations(chapterId),
    );
    await _db.annotationDao.mergeAnnotations(entries, chapterId: chapterId);

    log.debug(
      'refreshed chapter annotations',
      attributes: {
        'chapter_id': chapterId,
        'count': entries.length,
      },
    );
  }

  /// Creates a highlight of [selectedText] on the server and stores it. The
  /// server injects highlights into the pages it serves, so creating one
  /// needs a connection: errors are thrown.
  ///
  /// [xPath] and [endingXPath] locate the elements where the selection starts
  /// and ends, as computed by [KavitaXPathExtension.kavitaXPath]. [context]
  /// is the text around the selection, shown by the web reader.
  Future<AnnotationModel> createAnnotation({
    required int seriesId,
    required int volumeId,
    required int chapterId,
    required int page,
    required int ownerUserId,
    required String xPath,
    required String endingXPath,
    required String selectedText,
    required String context,
    required String comment,
    required int selectedSlotIndex,
    required bool containsSpoiler,
  }) async {
    final series = await _db.seriesDao.getSeries(seriesId);
    final created = await _client.create(
      AnnotationDto(
        xPath: xPath,
        endingXPath: endingXPath,
        selectedText: selectedText,
        highlightCount: selectedText.length,
        context: context,
        comment: QuillNote.delta(comment),
        commentHtml: QuillNote.html(comment),
        containsSpoiler: containsSpoiler,
        pageNumber: page,
        selectedSlotIndex: selectedSlotIndex,
        chapterId: chapterId,
        volumeId: volumeId,
        seriesId: seriesId,
        libraryId: series.libraryId,
        ownerUserId: ownerUserId,
      ),
    );

    final stored = await _db.annotationDao.saveRemote(
      created.toAnnotationCompanion(),
    );
    log.debug(
      'created annotation',
      attributes: {'chapter_id': chapterId, 'server_id': created.id},
    );
    return AnnotationModel.fromDatabaseModel(stored);
  }

  /// Changes the note, highlight slot and spoiler flag of [annotation]. The
  /// change is stored at once and sent to the server; if that fails, the
  /// next sync sends it. Returns whether the server has the change.
  Future<bool> updateAnnotation(
    AnnotationModel annotation, {
    required String comment,
    required int selectedSlotIndex,
    required bool containsSpoiler,
  }) async {
    await _db.annotationDao.updateLocal(
      annotation.id,
      AnnotationsCompanion(
        comment: Value(comment),
        selectedSlotIndex: Value(selectedSlotIndex),
        containsSpoiler: Value(containsSpoiler),
      ),
    );
    return _tryPush(annotation.id);
  }

  /// Deletes [annotation]. It disappears at once and the deletion is sent to
  /// the server; if that fails, the next sync sends it. Returns whether the
  /// server has the deletion.
  Future<bool> deleteAnnotation(AnnotationModel annotation) async {
    if (annotation.serverId == null) {
      await _db.annotationDao.deleteById(annotation.id);
      return true;
    }

    await _db.annotationDao.markDeleted(annotation.id);
    return _tryPush(annotation.id);
  }

  /// Sends the local changes of all annotations to the server.
  Future<void> pushAnnotations() async {
    for (final row in await _db.annotationDao.getDirty()) {
      try {
        await _push(row);
      } catch (e, stacktrace) {
        log.error(
          'could not push annotation',
          error: e,
          stacktrace: stacktrace,
        );
      }
    }
  }

  Future<bool> _tryPush(int id) async {
    final row = await _db.annotationDao.getAnnotation(id);
    if (row == null) return true;

    try {
      await _push(row);
      return true;
    } catch (e) {
      log.info('could not push annotation', attributes: {'error': e});
      return false;
    }
  }

  /// Sends the local changes of [row] to the server and stores the result.
  Future<void> _push(Annotation row) async {
    final serverId = row.serverId;
    if (serverId == null) return;

    if (row.deleted) {
      await _client.delete(serverId);
      await _db.annotationDao.deleteById(row.id);
      return;
    }

    // Update replaces the whole note: start from the server's copy so that
    // a note formatted in the web reader is only rewritten when changed.
    final remote = await _client.get(serverId);
    if (remote == null) {
      await _db.annotationDao.deleteById(row.id);
      return;
    }

    final comment = row.comment ?? '';
    final noteChanged = (remote.noteText ?? '') != comment;
    final updated = await _client.update(
      remote.copyWith(
        selectedSlotIndex: row.selectedSlotIndex,
        containsSpoiler: row.containsSpoiler,
        comment: noteChanged ? QuillNote.delta(comment) : remote.comment,
        commentHtml: noteChanged ? QuillNote.html(comment) : remote.commentHtml,
      ),
    );
    await _db.annotationDao.markPushed(row.id, updated.toAnnotationCompanion());
  }

  /// Fetch the highlight colors from the user preferences and replace the
  /// stored ones.
  Future<void> refreshHighlightSlots() async {
    final slots = await _client.getHighlightSlots();
    await _db.annotationDao.replaceHighlightSlots(
      slots.indexed.map((e) => e.$2.toHighlightSlotCompanion(e.$1)),
    );
  }

  static List<AnnotationsCompanion> _toCompanions(List<AnnotationDto> dtos) =>
      dtos
          .where((dto) => dto.id != null)
          .map((dto) => dto.toAnnotationCompanion())
          .toList();
}
