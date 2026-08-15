import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/data_constants.dart';
import 'package:kover/widgets/details/metadata_sections.dart';

part 'chapter_model.freezed.dart';
part 'chapter_model.g.dart';

@freezed
sealed class ChapterModel with _$ChapterModel {
  const ChapterModel._();

  const factory ChapterModel({
    required int id,
    required int seriesId,
    required int volumeId,
    required String title,
    required int pages,
    Format? format,
    String? summary,
    int? wordCount,
    double? avgHoursToRead,
    String? primaryColor,
    String? secondaryColor,
  }) = _ChapterModel;

  factory ChapterModel.fromJson(Map<String, Object?> json) =>
      _$ChapterModelFromJson(json);

  factory ChapterModel.fromDatabaseModel(Chapter table) {
    return ChapterModel(
      id: table.id,
      seriesId: table.seriesId,
      volumeId: table.volumeId,
      title: _cleanedTitle(table),
      pages: table.pages,
      format: table.format,
      summary: table.summary,
      wordCount: table.wordCount,
      avgHoursToRead: table.avgHoursToRead,
      primaryColor: table.primaryColor,
      secondaryColor: table.secondaryColor,
    );
  }

  static String _cleanedTitle(Chapter table) {
    if (table.title != null &&
        RegExp(
          '^(Chapter|Book) ${DataConstants.singleVolumeChapterMinNumber.toInt()}',
        ).hasMatch(table.title!)) {
      return table.titleName != null && table.titleName!.isNotEmpty
          ? table.titleName!
          : 'Single Volume';
    }

    final titles = {
      table.title,
      table.titleName,
    }.whereType<String>().where((t) => t.trim().isNotEmpty);

    if (titles.isEmpty) {
      return switch (table.format) {
        .epub => 'Book ${table.minNumber.toInt()}',
        .archive || .image => 'Chapter ${table.minNumber.toInt()}',
        _ => 'Untitled',
      };
    }

    if (titles.length > 1 && table.title!.contains(table.titleName!)) {
      return table.titleName!;
    }

    return titles.join(' - ');
  }
}

@freezed
sealed class ChapterMetadataModel
    with _$ChapterMetadataModel
    implements MetadataViewModel {
  const factory ChapterMetadataModel({
    required int chapterId,
    required String? summary,
    required int? releaseYear,
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
  }) = _ChapterMetadataModel;

  factory ChapterMetadataModel.fromDatabaseModel(
    ChapterMetadataWithRelations data,
  ) {
    return ChapterMetadataModel(
      chapterId: data.chapter.id,
      summary: data.chapter.summary,
      releaseYear: data.chapter.releaseDate.year,
      publicationStatus: data.chapter.publicationStatus,
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
