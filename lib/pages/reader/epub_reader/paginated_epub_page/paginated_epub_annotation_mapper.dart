import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';

/// Maps a stored annotation to the paginated EPUB render model.
///
/// Returns `null` when the annotation's selected highlight slot has no color.
PaginatedEpubAnnotation? toPaginatedEpubAnnotation(
  AnnotationModel annotation,
  List<HighlightSlotModel> slots,
) {
  final color = slots.colorForSlot(annotation.selectedSlotIndex);
  if (color == null) return null;

  return PaginatedEpubAnnotation(
    id: annotation.id,
    serverId: annotation.serverId,
    xpath: annotation.xPath,
    endXpath: annotation.endingXPath,
    selectedText: annotation.selectedText,
    color: color,
  );
}
