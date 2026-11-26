import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_helpers.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_annotation_sheet_provider.freezed.dart';
part 'epub_annotation_sheet_provider.g.dart';

@freezed
class EpubAnnotationSheetModel({
  required final AnnotationModel annotation,
  required final List<HighlightSlotModel> slots,
  required final String? chapterTitle,
  required final bool canModify,
}) with _$EpubAnnotationSheetModel;

@freezed
class EpubAnnotationDraftSheetModel({
  required final List<HighlightSlotModel> slots,
  required final String? chapterTitle,
}) with _$EpubAnnotationDraftSheetModel;

@riverpod
Future<EpubAnnotationSheetModel?> epubAnnotationSheet(
  Ref ref, {
  required int chapterId,
  required int annotationId,
}) async {
  final annotationFuture = ref.watch(
    annotationProvider(id: annotationId).future,
  );
  final slotsFuture = ref.watch(highlightSlotsProvider.future);
  final chaptersFuture = ref.watch(
    bookChaptersProvider(chapterId: chapterId).future,
  );
  final currentUserId = ref.watch(
    currentUserProvider.select((user) => user.value?.id),
  );

  final (annotation, slots, chapters) = await (
    annotationFuture,
    slotsFuture,
    chaptersFuture,
  ).wait;

  if (annotation == null) return null;

  return EpubAnnotationSheetModel(
    annotation: annotation,
    slots: slots,
    chapterTitle: chapterTitleForPage(chapters, annotation.pageNumber),
    canModify: currentUserId != null && annotation.ownerUserId == currentUserId,
  );
}

@riverpod
Future<EpubAnnotationDraftSheetModel> epubAnnotationDraftSheet(
  Ref ref, {
  required int chapterId,
  required int pageNumber,
}) async {
  final slotsFuture = ref.watch(highlightSlotsProvider.future);
  final chaptersFuture = ref.watch(
    bookChaptersProvider(chapterId: chapterId).future,
  );

  final (slots, chapters) = await (slotsFuture, chaptersFuture).wait;

  return EpubAnnotationDraftSheetModel(
    slots: slots,
    chapterTitle: chapterTitleForPage(chapters, pageNumber),
  );
}
