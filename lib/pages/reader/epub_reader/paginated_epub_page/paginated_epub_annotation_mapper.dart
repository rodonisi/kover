import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:material_ui/material_ui.dart';

/// Maps a stored annotation to the paginated EPUB render model.
///
/// Returns `null` when the annotation has no usable selection or its selected
/// highlight slot has no color.
PaginatedEpubAnnotation? toPaginatedEpubAnnotation(
  AnnotationModel annotation,
  List<HighlightSlotModel> slots,
) {
  final xpath = annotation.xPath;
  final selectedText = annotation.selectedText;
  if (xpath == null ||
      xpath.trim().isEmpty ||
      selectedText == null ||
      selectedText.trim().isEmpty) {
    return null;
  }

  final color = _colorForSlot(slots, annotation.selectedSlotIndex);
  if (color == null) return null;

  final endingXPath = annotation.endingXPath;
  return PaginatedEpubAnnotation(
    id: annotation.id,
    serverId: annotation.serverId,
    xpath: xpath,
    endXpath: endingXPath != null && endingXPath.trim().isNotEmpty
        ? endingXPath
        : xpath,
    selectedText: selectedText,
    color: color,
  );
}

Color? _colorForSlot(List<HighlightSlotModel> slots, int slotNumber) {
  for (final slot in slots) {
    if (slot.slotNumber == slotNumber) return slot.color;
  }

  return null;
}
