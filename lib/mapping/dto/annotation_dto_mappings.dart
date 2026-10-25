import 'package:drift/drift.dart';
import 'package:html/dom.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:material_ui/material_ui.dart';

extension AnnotationDtoMappings on AnnotationDto {
  AnnotationsCompanion toAnnotationCompanion() {
    return AnnotationsCompanion(
      serverId: Value(id),
      seriesId: Value(seriesId),
      volumeId: Value(volumeId),
      chapterId: Value(chapterId),
      page: Value(pageNumber ?? 0),
      xPath: Value(xPath ?? ''),
      endingXPath: Value(endingXPath),
      selectedText: Value(selectedText ?? ''),
      // Kavita escapes HTML in the plain text of the note.
      comment: Value(switch (commentPlainText) {
        final text? => DocumentFragment.html(text).text,
        null => comment,
      }),
      selectedSlotIndex: Value(selectedSlotIndex ?? 0),
      containsSpoiler: Value(containsSpoiler ?? false),
      ownerUserId: Value(ownerUserId),
      lastModified: Value(lastModifiedUtc),
      dirty: const Value(false),
      deleted: const Value(false),
    );
  }
}

extension HighlightSlotMappings on HighlightSlot {
  /// Maps the slot to a companion stored at [slotIndex], the slot's position
  /// in the user's preferences.
  HighlightSlotsCompanion toHighlightSlotCompanion(int slotIndex) {
    return HighlightSlotsCompanion(
      slotIndex: Value(slotIndex),
      color: Value(
        Color.fromRGBO(
          color?.r ?? 0,
          color?.g ?? 0,
          color?.b ?? 0,
          color?.a ?? 1,
        ).toARGB32(),
      ),
    );
  }
}
