import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/age_rating_mappings.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension AnnotationDtoMappings on AnnotationDto {
  AnnotationsCompanion? toAnnotationCompanion({int? localId}) {
    final serverId = id;
    if (localId == null && serverId == null) return null;

    final xPath = this.xPath;
    final selectedText = this.selectedText;
    final pageNumber = this.pageNumber;
    final selectedSlotIndex = this.selectedSlotIndex;
    final created = createdUtc?.normalizeUtc();
    if (xPath == null ||
        xPath.trim().isEmpty ||
        selectedText == null ||
        selectedText.trim().isEmpty ||
        pageNumber == null ||
        selectedSlotIndex == null ||
        created == null) {
      return null;
    }

    final endingXPath = this.endingXPath;
    final resolvedEndingXPath =
        endingXPath != null && endingXPath.trim().isNotEmpty
        ? endingXPath
        : xPath;
    final lastModified = lastModifiedUtc?.normalizeUtc() ?? created;

    return .insert(
      id: Value.absentIfNull(localId),
      serverId: Value.absentIfNull(serverId),
      seriesId: seriesId,
      volumeId: volumeId,
      chapterId: chapterId,
      libraryId: libraryId,
      ownerUserId: ownerUserId,
      ownerUsername: Value(ownerUsername),
      xPath: xPath,
      endingXPath: resolvedEndingXPath,
      selectedText: selectedText,
      comment: Value(comment ?? '{}'),
      commentHtml: Value(commentHtml),
      context: Value(context),
      highlightCount: Value(highlightCount),
      containsSpoiler: Value(containsSpoiler ?? false),
      pageNumber: pageNumber,
      selectedSlotIndex: selectedSlotIndex,
      likes: Value(likes ?? const []),
      ageRating: Value(ageRating?.toLocal()),
      created: created,
      lastModified: lastModified,
      dirty: const Value(false),
      removed: const Value(false),
    );
  }
}

extension AnnotationMappings on Annotation {
  AnnotationDto toAnnotationDto() {
    return AnnotationDto(
      id: serverId,
      xPath: xPath,
      endingXPath: endingXPath,
      selectedText: selectedText,
      comment: comment,
      commentHtml: commentHtml,
      context: context,
      highlightCount: highlightCount,
      containsSpoiler: containsSpoiler,
      pageNumber: pageNumber,
      selectedSlotIndex: selectedSlotIndex,
      likes: likes,
      chapterId: chapterId,
      volumeId: volumeId,
      seriesId: seriesId,
      libraryId: libraryId,
      ownerUserId: ownerUserId,
      ownerUsername: ownerUsername,
      ageRating: ageRating?.toApi(),
      createdUtc: created,
      lastModifiedUtc: lastModified,
    );
  }
}
