import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/volume_model.dart';

part 'series_model.freezed.dart';
part 'series_model.g.dart';

@freezed
sealed class SeriesModel with _$SeriesModel {
  const SeriesModel._();

  const factory SeriesModel({
    required int id,
    required int libraryId,
    required String name,
    required Format format,
    required int pages,
    required double avgHoursToRead,
    required int? wordCount,
    required String? primaryColor,
    required String? secondaryColor,
  }) = _SeriesModel;

  factory SeriesModel.fromJson(Map<String, Object?> json) =>
      _$SeriesModelFromJson(json);

  factory SeriesModel.fromDatabaseModel(SeriesData table) {
    return SeriesModel(
      id: table.id,
      libraryId: table.libraryId,
      name: table.name,
      format: table.format,
      pages: table.pages,
      avgHoursToRead: table.avgHoursToRead ?? 0,
      wordCount: table.wordCount,
      primaryColor: table.primaryColor,
      secondaryColor: table.secondaryColor,
    );
  }
}

@freezed
sealed class SeriesDetailModel with _$SeriesDetailModel {
  const factory SeriesDetailModel({
    required List<ChapterModel> storyline,
    required List<VolumeModel> volumes,
    required List<ChapterModel> chapters,
    required List<ChapterModel> specials,
    required List<ChapterModel> unreadChapters,
    required List<VolumeModel> unreadVolumes,
  }) = _SeriesDetailModel;

  factory SeriesDetailModel.fromJson(Map<String, Object?> json) =>
      _$SeriesDetailModelFromJson(json);

  factory SeriesDetailModel.fromDatabaseModel(SeriesDetailWithRelations model) {
    return SeriesDetailModel(
      storyline: model.storylineChapters
          .map(ChapterModel.fromDatabaseModel)
          .toList(),
      volumes: model.volumes.map(VolumeModel.fromDatabaseModel).toList(),
      chapters: model.chapters.map(ChapterModel.fromDatabaseModel).toList(),
      specials: model.specials.map(ChapterModel.fromDatabaseModel).toList(),
      unreadChapters: model.unreadChapters
          .map(ChapterModel.fromDatabaseModel)
          .toList(),
      unreadVolumes: model.unreadVolumes
          .map(VolumeModel.fromDatabaseModel)
          .toList(),
    );
  }
}

@freezed
sealed class PersonModel with _$PersonModel {
  const factory PersonModel({
    required int id,
    required String name,
  }) = _PersonModel;

  factory PersonModel.fromJson(Map<String, Object?> json) =>
      _$PersonModelFromJson(json);

  factory PersonModel.fromPersonDto(PersonDto dto) {
    return PersonModel(
      id: dto.id!,
      name: dto.name!,
    );
  }
}

@freezed
sealed class GenreModel with _$GenreModel {
  const factory GenreModel({
    required int id,
    required String name,
  }) = _GenreModel;

  factory GenreModel.fromJson(Map<String, Object?> json) =>
      _$GenreModelFromJson(json);

  factory GenreModel.fromGenreTagDto(GenreTagDto dto) {
    return GenreModel(
      id: dto.id!,
      name: dto.title!,
    );
  }
}

@freezed
sealed class SeriesMetadataModel with _$SeriesMetadataModel {
  const factory SeriesMetadataModel({
    required int seriesId,
    required int totalChapters,
    required int? releaseYear,
    required String? summary,
    required List<PersonModel> writers,
    required List<GenreModel> genres,
  }) = _SeriesMetadataModel;

  factory SeriesMetadataModel.fromJson(Map<String, Object?> json) =>
      _$SeriesMetadataModelFromJson(json);

  factory SeriesMetadataModel.fromSeriesMetadataDto(SeriesMetadataDto dto) {
    return SeriesMetadataModel(
      seriesId: dto.seriesId!,
      totalChapters: dto.totalCount!,
      releaseYear: dto.releaseYear,
      summary: dto.summary,
      writers: dto.writers?.map(PersonModel.fromPersonDto).toList() ?? [],
      genres: dto.genres?.map(GenreModel.fromGenreTagDto).toList() ?? [],
    );
  }

  factory SeriesMetadataModel.fromDatabaseModel(
    SeriesMetadataWithRelations data,
  ) {
    return SeriesMetadataModel(
      seriesId: data.metadata?.seriesId ?? 0,
      totalChapters: 0,
      releaseYear: data.metadata?.releaseYear,
      summary: data.metadata?.summary,
      writers: data.writers
          .map(
            (writer) => PersonModel(
              id: writer.id,
              name: writer.name,
            ),
          )
          .toList(),
      genres: data.genres
          .map(
            (genre) => GenreModel(
              id: genre.id,
              name: genre.label,
            ),
          )
          .toList(),
    );
  }
}
