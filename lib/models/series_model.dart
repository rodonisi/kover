import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/widgets/details/metadata_sections.dart';

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
}

@freezed
sealed class GenreModel with _$GenreModel {
  const factory GenreModel({
    required int id,
    required String name,
  }) = _GenreModel;
}

@freezed
sealed class TagModel with _$TagModel {
  const factory TagModel({
    required int id,
    required String name,
  }) = _TagModel;
}

@freezed
sealed class SeriesMetadataModel
    with _$SeriesMetadataModel
    implements MetadataViewModel {
  const factory SeriesMetadataModel({
    required int seriesId,
    required int totalChapters,
    required int? releaseYear,
    required String? summary,
    required AgeRating ageRating,
    required String? language,
    required PublicationStatus publicationStatus,
    required List<PersonModel> writers,
    required List<PersonModel> coverArtists,
    required List<PersonModel> publishers,
    required List<PersonModel> characters,
    required List<PersonModel> pencillers,
    required List<PersonModel> inkers,
    required List<PersonModel> imprints,
    required List<PersonModel> colorists,
    required List<PersonModel> letterers,
    required List<PersonModel> editors,
    required List<PersonModel> translators,
    required List<PersonModel> teams,
    required List<PersonModel> locations,
    required List<GenreModel> genres,
    required List<TagModel> tags,
  }) = _SeriesMetadataModel;

  factory SeriesMetadataModel.fromDatabaseModel(
    SeriesMetadataWithRelations data,
  ) {
    return SeriesMetadataModel(
      seriesId: data.metadata.seriesId,
      totalChapters: 0,
      releaseYear: data.metadata.releaseYear,
      summary: data.metadata.summary,
      ageRating: data.metadata.ageRating,
      publicationStatus: data.metadata.publicationStatus,
      language: data.metadata.language,
      writers: _mapPersonList(data.writers),
      coverArtists: _mapPersonList(data.coverArtists),
      publishers: _mapPersonList(data.publishers),
      characters: _mapPersonList(data.characters),
      pencillers: _mapPersonList(data.pencillers),
      inkers: _mapPersonList(data.inkers),
      imprints: _mapPersonList(data.imprints),
      colorists: _mapPersonList(data.colorists),
      letterers: _mapPersonList(data.letterers),
      editors: _mapPersonList(data.editors),
      translators: _mapPersonList(data.translators),
      teams: _mapPersonList(data.teams),
      locations: _mapPersonList(data.locations),
      genres: data.genres
          .map(
            (genre) => GenreModel(
              id: genre.id,
              name: genre.label,
            ),
          )
          .toList(),
      tags: data.tags
          .map(
            (tag) => TagModel(
              id: tag.id,
              name: tag.label,
            ),
          )
          .toList(),
    );
  }
}

List<PersonModel> _mapPersonList(List<PeopleData> people) {
  return people
      .map(
        (person) => PersonModel(
          id: person.id,
          name: person.name,
        ),
      )
      .toList();
}
