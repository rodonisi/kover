import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/models/chapter_model.dart';

part 'volume_model.freezed.dart';

@freezed
class VolumeDetailsModel({
  required final int id,
  required final String name,
  required final int seriesId,
  required final List<ChapterModel> chapters,
  required final int pages,
  final double? avgHoursToRead,
  final int? wordCount,
  final String? primaryColor,
  final String? secondaryColor,
}) with _$VolumeDetailsModel {
  factory VolumeDetailsModel.fromDatabaseModel(VolumeWithRelations data) {
    return VolumeDetailsModel(
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

@freezed
class VolumeModel({
  required final int id,
  required final String name,
  required final int seriesId,
  required final int pages,
  final double? avgHoursToRead,
  final int? wordCount,
  final String? primaryColor,
  final String? secondaryColor,
}) with _$VolumeModel {
  factory VolumeModel.fromDatabaseModel(Volume data) {
    return VolumeModel(
      id: data.id,
      seriesId: data.seriesId,
      name: data.name ?? '',
      pages: data.pages,
      avgHoursToRead: data.avgHoursToRead,
      wordCount: data.wordCount,
      primaryColor: data.primaryColor,
      secondaryColor: data.secondaryColor,
    );
  }
}
