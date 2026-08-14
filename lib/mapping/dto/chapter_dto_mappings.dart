import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/mapping/dto/age_rating_mappings.dart';
import 'package:kover/mapping/dto/person_dto_mappings.dart';
import 'package:kover/mapping/dto/publication_status_mappings.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension ChapterDtoMappings on ChapterDto {
  static Iterable<PeopleCompanion> convertPersonDtoList(
    Iterable<PersonDto>? l,
  ) {
    return (l ?? []).map((e) => e.toPeopleCompanion());
  }

  ChapterWithRelationsCompanion toChapterCompanions() {
    final genresList = genres?.toList() ?? [];
    final tagsList = tags?.toList() ?? [];

    return ChapterWithRelationsCompanion(
      chapter: ChaptersCompanion(
        id: Value(id!),
        volumeId: Value(volumeId!),
        title: Value(title),
        titleName: Value(titleName),
        description: Value(summary),
        summary: Value(summary),
        isbn: Value(isbn),
        format: Value(
          format != null ? Format.fromDtoFormat(format!) : .unknown,
        ),
        language: Value.absentIfNull(language),
        minNumber: Value(minNumber!),
        maxNumber: Value(maxNumber!),
        sortOrder: Value.absentIfNull(sortOrder),
        pages: Value(pages!),
        wordCount: Value.absentIfNull(wordCount),
        minHoursToRead: Value.absentIfNull(minHoursToRead),
        maxHoursToRead: Value.absentIfNull(maxHoursToRead),
        avgHoursToRead: Value.absentIfNull(avgHoursToRead),
        ageRating: Value(ageRating?.toLocal() ?? .unknown),
        primaryColor: Value.absentIfNull(primaryColor),
        secondaryColor: Value.absentIfNull(secondaryColor),
        isSpecial: Value.absentIfNull(isSpecial),
        releaseDate: Value.absentIfNull(releaseDate?.normalizeUtc()),
        publicationStatus: Value(
          publicationStatus?.toLocal() ?? .unknown,
        ),
        webLinks: Value.absentIfNull(webLinks),
        created: Value.absentIfNull(createdUtc?.normalizeUtc()),
        lastModified: Value.absentIfNull(lastModifiedUtc?.normalizeUtc()),
        remoteLastRead: Value.absentIfNull(
          lastReadingProgressUtc?.normalizeUtc(),
        ),
      ),
      writers: convertPersonDtoList(writers),
      coverArtists: convertPersonDtoList(coverArtists),
      publishers: convertPersonDtoList(publishers),
      characters: convertPersonDtoList(characters),
      pencillers: convertPersonDtoList(pencillers),
      inkers: convertPersonDtoList(inkers),
      imprints: convertPersonDtoList(imprints),
      colorists: convertPersonDtoList(colorists),
      letterers: convertPersonDtoList(letterers),
      editors: convertPersonDtoList(editors),
      translators: convertPersonDtoList(translators),
      teams: convertPersonDtoList(teams),
      locations: convertPersonDtoList(locations),
      genres: genresList
          .map(
            (genre) => GenresCompanion.insert(
              id: Value(genre.id!),
              label: genre.title!,
            ),
          )
          .toList(),
      tags: tagsList
          .map(
            (tag) => TagsCompanion.insert(
              id: Value(tag.id!),
              label: tag.title!,
            ),
          )
          .toList(),
    );
  }
}
