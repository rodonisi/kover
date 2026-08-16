import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/data_constants.dart';
import 'package:kover/widgets/details/metadata_sections.dart';

part 'chapter_model.freezed.dart';

@freezed
sealed class ChapterModel with _$ChapterModel implements MetadataViewModel {
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
    @Default(PublicationStatus.unknown) PublicationStatus publicationStatus,
    int? releaseYear,
    @Default([]) List<PersonModel> writers,
    @Default([]) List<PersonModel> coverArtists,
    @Default([]) List<PersonModel> publishers,
    @Default([]) List<PersonModel> characters,
    @Default([]) List<PersonModel> pencillers,
    @Default([]) List<PersonModel> inkers,
    @Default([]) List<PersonModel> imprints,
    @Default([]) List<PersonModel> colorists,
    @Default([]) List<PersonModel> letterers,
    @Default([]) List<PersonModel> editors,
    @Default([]) List<PersonModel> translators,
    @Default([]) List<PersonModel> teams,
    @Default([]) List<PersonModel> locations,
    @Default([]) List<GenreModel> genres,
    @Default([]) List<TagModel> tags,
  }) = _ChapterModel;

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
      publicationStatus: table.publicationStatus,
      releaseYear: table.releaseDate.year,
    );
  }

  factory ChapterModel.fromRelations(
    ChapterModel chapter,
    ChapterRelations relations,
  ) {
    return chapter.copyWith(
      writers: _mapPersonList(relations.writers),
      coverArtists: _mapPersonList(relations.coverArtists),
      publishers: _mapPersonList(relations.publishers),
      characters: _mapPersonList(relations.characters),
      pencillers: _mapPersonList(relations.pencillers),
      inkers: _mapPersonList(relations.inkers),
      imprints: _mapPersonList(relations.imprints),
      colorists: _mapPersonList(relations.colorists),
      letterers: _mapPersonList(relations.letterers),
      editors: _mapPersonList(relations.editors),
      translators: _mapPersonList(relations.translators),
      teams: _mapPersonList(relations.teams),
      locations: _mapPersonList(relations.locations),
      genres: relations.genres
          .map(
            (genre) => GenreModel(
              id: genre.id,
              name: genre.label,
            ),
          )
          .toList(),
      tags: relations.tags
          .map(
            (tag) => TagModel(
              id: tag.id,
              name: tag.label,
            ),
          )
          .toList(),
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
