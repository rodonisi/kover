import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'annotation_model.freezed.dart';

@freezed
class AnnotationModel({
  required final int id,
  final int? serverId,
  required final int chapterId,
  required final int pageNumber,
  required final int ownerUserId,
  final String? ownerUsername,
  required final String xPath,
  required final String endingXPath,
  required final String selectedText,
  final String? comment,
  final String? commentHtml,
  final String? commentPlainText,
  final bool containsSpoiler = false,
  final int selectedSlotIndex = 0,
  required final DateTime created,
  required final DateTime lastModified,
}) with _$AnnotationModel {
  factory fromDatabaseModel(Annotation data) => AnnotationModel(
    id: data.id,
    serverId: data.serverId,
    chapterId: data.chapterId,
    pageNumber: data.pageNumber,
    ownerUserId: data.ownerUserId,
    ownerUsername: data.ownerUsername,
    xPath: data.xPath,
    endingXPath: data.endingXPath,
    selectedText: data.selectedText,
    comment: data.comment,
    commentHtml: data.commentHtml,
    commentPlainText: data.commentPlainText,
    containsSpoiler: data.containsSpoiler,
    selectedSlotIndex: data.selectedSlotIndex,
    created: data.created,
    lastModified: data.lastModified,
  );
}
