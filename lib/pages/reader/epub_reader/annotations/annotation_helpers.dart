import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/utils/annotation_comment.dart';
import 'package:material_ui/material_ui.dart';

/// The comment as plain text. Kavita's plain-text copy has no line breaks, so
/// it is only used when the stored comment cannot be decoded.
String commentText(AnnotationModel annotation) {
  return AnnotationComment.toPlainText(annotation.comment) ??
      annotation.commentPlainText ??
      '';
}

Color? colorForSlot(List<HighlightSlotModel> slots, int slotNumber) {
  return slots
      .where((slot) => slot.slotNumber == slotNumber)
      .firstOrNull
      ?.color;
}

bool hasColor(List<HighlightSlotModel> slots, int slotNumber) {
  return colorForSlot(slots, slotNumber) != null;
}

/// The slot preselected for a new annotation: Kavita's default slot `0`, or
/// the first slot that has a color.
int defaultSlot(List<HighlightSlotModel> slots) {
  if (hasColor(slots, 0)) return 0;

  return slots.where((slot) => slot.color != null).firstOrNull?.slotNumber ?? 0;
}

/// Returns the title of the latest TOC entry starting at or before [page].
String? chapterTitleForPage(List<BookChapterModel> chapters, int page) {
  String? bestTitle;
  var bestPage = -1;

  void visit(List<BookChapterModel> nodes) {
    for (final node in nodes) {
      final title = node.title.trim();
      if (node.page <= page && node.page >= bestPage && title.isNotEmpty) {
        bestPage = node.page;
        bestTitle = title;
      }
      if (node.children.isNotEmpty) {
        visit(node.children);
      }
    }
  }

  visit(chapters);
  return bestTitle;
}

String formatAttribution(
  AppLocalizations l, {
  required int pageNumber,
  required String? chapterTitle,
}) {
  final displayPage = pageNumber + 1;
  return switch (chapterTitle) {
    final chapter? when chapter.isNotEmpty => l.annotationPageChapterLocation(
      displayPage,
      chapter,
    ),
    _ => l.annotationPageLocation(displayPage),
  };
}
