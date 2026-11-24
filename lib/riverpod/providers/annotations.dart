import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'annotations.g.dart';

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

/// Coordinates annotation edits and removal through the repository.
@riverpod
class AnnotationActions extends _$AnnotationActions {
  @override
  void build() {}

  /// Saves a plain-text comment and highlight slot for the annotation.
  Future<void> save({
    required int id,
    required String? comment,
    required bool containsSpoiler,
    required int selectedSlotIndex,
  }) {
    return ref
        .read(annotationRepositoryProvider)
        .updateAnnotation(
          id: id,
          comment: comment,
          commentHtml: null,
          commentPlainText: comment,
          containsSpoiler: containsSpoiler,
          selectedSlotIndex: selectedSlotIndex,
        );
  }

  /// Removes the annotation locally and attempts to remove its server copy.
  Future<void> remove(int id) {
    return ref.read(annotationRepositoryProvider).removeAnnotation(id);
  }
}
