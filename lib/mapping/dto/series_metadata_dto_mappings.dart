import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/database/tables/series_metadata.dart';

extension SeriesMetadataDtoMappings on SeriesMetadataDto {
  SeriesMetadataCompanions toSeriesMetadataCompanions() {
    final metadataId = id!;
    final writersList = writers?.toList() ?? [];
    final genresList = genres?.toList() ?? [];
    final tagsList = tags?.toList() ?? [];

    return SeriesMetadataCompanions(
      metadata: SeriesMetadataCompanion(
        id: Value(metadataId),
        seriesId: Value(seriesId!),
        summary: Value(summary),
        ageRating: Value.absentIfNull(ageRating?.value),
        releaseYear: Value(releaseYear ?? 0),
        language: Value(language ?? ''),
        lastUpdated: Value(DateTime.timestamp()),
      ),
      writers: writersList
          .map(
            (writer) => PeopleCompanion(
              id: Value(writer.id!),
              name: Value(writer.name!),
            ),
          )
          .toList(),
      genres: genresList
          .map(
            (genre) => GenresCompanion(
              id: Value(genre.id!),
              label: Value(genre.title!),
            ),
          )
          .toList(),
      tags: tagsList
          .map(
            (tag) => TagsCompanion(
              id: Value(tag.id!),
              label: Value(tag.title!),
            ),
          )
          .toList(),
      peopleRoles: writersList
          .map(
            (writer) => SeriesPeopleRolesCompanion(
              seriesMetadataId: Value(metadataId),
              personId: Value(writer.id!),
              role: const Value(PeopleRole.writer),
            ),
          )
          .toList(),
      seriesGenres: genresList
          .map(
            (genre) => SeriesGenresCompanion(
              seriesMetadataId: Value(metadataId),
              genreId: Value(genre.id!),
            ),
          )
          .toList(),
      seriesTags: tagsList
          .map(
            (tag) => SeriesTagsCompanion(
              seriesMetadataId: Value(metadataId),
              tagId: Value(tag.id!),
            ),
          )
          .toList(),
    );
  }
}
