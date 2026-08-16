import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/models/chapter_model.dart';

part 'volume_model.freezed.dart';

@freezed
sealed class VolumeModel with _$VolumeModel {
  const VolumeModel._();

  const factory VolumeModel({
    required int id,
    required String name,
    required int seriesId,
    required List<ChapterModel> chapters,
    required int pages,
    double? avgHoursToRead,
    int? wordCount,
    String? primaryColor,
    String? secondaryColor,
  }) = _VolumeModel;

  factory VolumeModel.fromDatabaseModel(VolumeWithRelations data) {
    return VolumeModel(
      id: data.volume.id,
      seriesId: data.volume.seriesId,
      name: data.volume.name ?? '',
      chapters: data.chapters.map(ChapterModel.fromDatabaseModel).toList(),
      pages: data.volume.pages,
      avgHoursToRead: data.volume.avgHoursToRead,
      wordCount: data.volume.wordCount,
      primaryColor: data.volume.primaryColor,
      secondaryColor: data.volume.secondaryColor,
    );
  }
}
