import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'annotation_model.freezed.dart';

@freezed
class AnnotationModel({
  required final int id,
  final int? serverId,
  required final int seriesId,
  required final int volumeId,
  required final int chapterId,
  required final int page,
  required final String xPath,
  final String? endingXPath,
  required final String selectedText,
  final String? comment,
  required final int selectedSlotIndex,
  required final bool containsSpoiler,
  required final int ownerUserId,
  final DateTime? lastModified,
}) with _$AnnotationModel {
  factory fromDatabaseModel(Annotation data) => AnnotationModel(
    id: data.id,
    serverId: data.serverId,
    seriesId: data.seriesId,
    volumeId: data.volumeId,
    chapterId: data.chapterId,
    page: data.page,
    xPath: data.xPath,
    endingXPath: data.endingXPath,
    selectedText: data.selectedText,
    comment: data.comment,
    selectedSlotIndex: data.selectedSlotIndex,
    containsSpoiler: data.containsSpoiler,
    ownerUserId: data.ownerUserId,
    lastModified: data.lastModified,
  );
}
