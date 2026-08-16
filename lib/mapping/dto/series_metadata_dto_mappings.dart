import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/mapping/dto/age_rating_mappings.dart';
import 'package:kover/mapping/dto/person_dto_mappings.dart';
import 'package:kover/mapping/dto/publication_status_mappings.dart';

extension SeriesMetadataDtoMappings on SeriesMetadataDto {
  static Iterable<PeopleCompanion> convertPersonDtoList(
    Iterable<PersonDto>? l,
  ) {
    return (l ?? []).map((e) => e.toPeopleCompanion());
  }

  SeriesMetadataCompanions toSeriesMetadataCompanions() {
    final genresList = genres?.toList() ?? [];
    final tagsList = tags?.toList() ?? [];

    return SeriesMetadataCompanions(
      metadata: SeriesMetadataCompanion.insert(
        id: Value(id!),
        seriesId: seriesId!,
        summary: Value(summary),
        ageRating: ageRating?.toLocal() ?? .unknown,
        releaseYear: Value(releaseYear),
        language: Value(language),
        lastUpdated: Value(DateTime.timestamp()),
        maxCount: maxCount ?? 0,
        totalCount: totalCount ?? 0,
        publicationStatus: publicationStatus?.toLocal() ?? .unknown,
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
