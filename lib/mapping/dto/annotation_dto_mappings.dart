import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/age_rating_mappings.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension AnnotationDtoMappings on AnnotationDto {
  AnnotationsCompanion toAnnotationCompanion({int? localId}) {
    return .insert(
      id: Value.absentIfNull(localId),
      serverId: Value.absentIfNull(id),
      seriesId: seriesId,
      volumeId: volumeId,
      chapterId: chapterId,
      libraryId: libraryId,
      ownerUserId: ownerUserId,
      ownerUsername: Value(ownerUsername),
      xPath: Value(xPath),
      endingXPath: Value(endingXPath),
      selectedText: Value(selectedText),
      comment: Value(comment),
      commentHtml: Value(commentHtml),
      commentPlainText: Value(commentPlainText),
      chapterTitle: Value(chapterTitle),
      context: Value(context),
      highlightCount: Value(highlightCount),
      containsSpoiler: Value(containsSpoiler),
      pageNumber: Value(pageNumber),
      selectedSlotIndex: Value(selectedSlotIndex),
      likes: Value(likes ?? const []),
      seriesName: Value(seriesName),
      libraryName: Value(libraryName),
      ageRating: Value(ageRating?.toLocal()),
      created: Value(createdUtc?.normalizeUtc()),
      lastModified: Value(lastModifiedUtc?.normalizeUtc()),
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
      commentPlainText: commentPlainText,
      chapterTitle: chapterTitle,
      context: context,
      highlightCount: highlightCount,
      containsSpoiler: containsSpoiler,
      pageNumber: pageNumber,
      selectedSlotIndex: selectedSlotIndex,
      likes: likes,
      seriesName: seriesName,
      libraryName: libraryName,
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
