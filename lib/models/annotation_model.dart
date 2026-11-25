import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'annotation_model.freezed.dart';

/// UI-facing representation of a stored annotation.
@freezed
class AnnotationModel({
  required final int id,
  final int? serverId,
  required final int chapterId,
  final int? pageNumber,
  final String? ownerUsername,
  final String? xPath,
  final String? endingXPath,
  final String? selectedText,
  final String? comment,
  final String? commentPlainText,
  final bool containsSpoiler = false,
  final int selectedSlotIndex = 0,
  final DateTime? created,
  final DateTime? lastModified,
}) with _$AnnotationModel {
  factory fromDatabaseModel(Annotation data) => AnnotationModel(
    id: data.id,
    serverId: data.serverId,
    chapterId: data.chapterId,
    pageNumber: data.pageNumber,
    ownerUsername: data.ownerUsername,
    xPath: data.xPath,
    endingXPath: data.endingXPath,
    selectedText: data.selectedText,
    comment: data.comment,
    commentPlainText: data.commentPlainText,
    containsSpoiler: data.containsSpoiler ?? false,
    selectedSlotIndex: data.selectedSlotIndex,
    created: data.created,
    lastModified: data.lastModified,
  );
}
