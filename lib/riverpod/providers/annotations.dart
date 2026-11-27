import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/utils/annotation_comment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'annotations.g.dart';

/// Watch the locally stored annotation with [id].
@riverpod
Stream<AnnotationModel?> annotation(Ref ref, {required int id}) {
  return ref.watch(annotationRepositoryProvider).watchAnnotation(id: id);
}

/// Watch the locally stored annotations for [chapterId].
@riverpod
Stream<List<AnnotationModel>> chapterAnnotations(
  Ref ref, {
  required int chapterId,
}) {
  return ref
      .watch(annotationRepositoryProvider)
      .watchAnnotations(chapterId: chapterId);
}

/// Watch the user's configured highlight slots.
@riverpod
Stream<List<HighlightSlotModel>> highlightSlots(Ref ref) {
  return ref.watch(annotationRepositoryProvider).watchHighlightSlots();
}

/// Coordinates annotation creation, edits and removal through the repository.
@riverpod
class AnnotationActions extends _$AnnotationActions {
  @override
  void build() {}

  /// Creates an annotation for the text selected in [draft] on [pageNumber]
  /// of the chapter with [chapterId].
  Future<void> create({
    required int chapterId,
    required int pageNumber,
    required AnnotationDraft draft,
    required quill.Document? comment,
    bool containsSpoiler = false,
    required int selectedSlotIndex,
  }) async {
    // Read before any await: the provider can be disposed while it loads.
    final annotations = ref.read(annotationRepositoryProvider);
    final chapters = ref.read(chaptersRepositoryProvider);
    final seriesRepository = ref.read(seriesRepositoryProvider);
    final userFuture = ref.read(currentUserProvider.future);

    final user = await userFuture;
    final chapter = await chapters.getChapter(chapterId: chapterId);
    final series = await seriesRepository.getSeries(
      seriesId: chapter.seriesId,
    );
    final encoded = comment == null
        ? AnnotationComment.empty
        : AnnotationComment.fromDocument(comment);

    await annotations.addAnnotation(
      seriesId: series.id,
      volumeId: chapter.volumeId,
      chapterId: chapter.id,
      libraryId: series.libraryId,
      ownerUserId: user.id,
      ownerUsername: user.username,
      xPath: draft.xPath,
      endingXPath: draft.endingXPath,
      selectedText: draft.selectedText,
      comment: encoded.comment,
      commentHtml: encoded.commentHtml,
      context: draft.context,
      // Kavita stores the number of selected characters.
      highlightCount: draft.selectedText.length,
      containsSpoiler: containsSpoiler,
      pageNumber: pageNumber,
      selectedSlotIndex: selectedSlotIndex,
    );
  }

  /// Saves a rich-text comment and highlight slot for the annotation.
  Future<void> save({
    required int id,
    required quill.Document? comment,
    required bool containsSpoiler,
    required int selectedSlotIndex,
  }) async {
    final annotations = ref.read(annotationRepositoryProvider);
    final user = await ref.read(currentUserProvider.future);
    final encoded = comment == null
        ? AnnotationComment.empty
        : AnnotationComment.fromDocument(comment);
    await annotations.updateAnnotation(
      id: id,
      ownerUserId: user.id,
      comment: encoded.comment,
      commentHtml: encoded.commentHtml,
      containsSpoiler: containsSpoiler,
      selectedSlotIndex: selectedSlotIndex,
    );
  }

  /// Removes the annotation locally and attempts to remove its server copy.
  Future<void> remove(int id) async {
    final annotations = ref.read(annotationRepositoryProvider);
    final user = await ref.read(currentUserProvider.future);
    await annotations.removeAnnotation(id, ownerUserId: user.id);
  }
}
