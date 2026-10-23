import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:kover/utils/logging.dart';
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

  /// Fetch the annotations of [chapterId] from the server and replace the
  /// stored ones.
  Future<void> refreshChapterAnnotations({required int chapterId}) async {
    final dtos = await _client.getChapterAnnotations(chapterId);
    final entries = dtos
        .where((dto) => dto.id != null)
        .map((dto) => dto.toAnnotationCompanion())
        .toList();

    await _db.annotationDao.replaceChapterAnnotations(
      chapterId: chapterId,
      entries: entries,
    );

    log.debug(
      'refreshed chapter annotations',
      attributes: {
        'chapter_id': chapterId,
        'count': entries.length,
      },
    );
  }

  /// Fetch the highlight colors from the user preferences and replace the
  /// stored ones.
  Future<void> refreshHighlightSlots() async {
    final slots = await _client.getHighlightSlots();
    await _db.annotationDao.replaceHighlightSlots(
      slots.indexed.map((e) => e.$2.toHighlightSlotCompanion(e.$1)),
    );
  }
}
