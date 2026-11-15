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
