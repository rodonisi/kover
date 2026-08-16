import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/models/enums/person_role.dart';
import 'package:rxdart/rxdart.dart';

part 'series_metadata_dao.g.dart';

@DriftAccessor(
  tables: [
    SeriesMetadata,
    People,
    Genres,
    Tags,
    SeriesPeopleRoles,
    SeriesGenres,
    SeriesTags,
  ],
)
class SeriesMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$SeriesMetadataDaoMixin {
  SeriesMetadataDao(super.attachedDatabase);

  /// Get series metadata for series [seriesId]
  Stream<SeriesMetadataWithRelations> watchSeriesMetadata(int seriesId) {
    final metadataQuery = select(seriesMetadata)
      ..where((t) => t.seriesId.equals(seriesId));

    return metadataQuery.watchSingleOrNull().whereNotNull().switchMap((
      metadata,
    ) {
      final tagsStream =
          (select(tags).join([
                innerJoin(seriesTags, seriesTags.tagId.equalsExp(tags.id)),
              ])..where(seriesTags.seriesMetadataId.equals(metadata.id)))
              .watch()
              .map((rows) => rows.map((r) => r.readTable(tags)).toList());

      final genresStream =
          (select(genres).join([
                innerJoin(
                  seriesGenres,
                  seriesGenres.genreId.equalsExp(genres.id),
                ),
              ])..where(seriesGenres.seriesMetadataId.equals(metadata.id)))
              .watch()
              .map((rows) => rows.map((r) => r.readTable(genres)).toList());

      final peopleStream =
          (select(people).join([
                innerJoin(
                  seriesPeopleRoles,
                  seriesPeopleRoles.personId.equalsExp(people.id),
                ),
              ])..where(seriesPeopleRoles.seriesMetadataId.equals(metadata.id)))
              .watch()
              .map((rows) {
                final map = <PersonRole, List<PeopleData>>{};
                for (final row in rows) {
                  final person = row.readTable(people);
                  final role = row.readTable(seriesPeopleRoles).role;
                  map.putIfAbsent(role, () => []).add(person);
                }
                return map;
              });

      return Rx.combineLatest3(tagsStream, genresStream, peopleStream, (
        t,
        g,
        p,
      ) {
        return SeriesMetadataWithRelations(
          metadata: metadata,
          tags: t,
          genres: g,
          writers: p[PersonRole.writer] ?? [],
          publishers: p[PersonRole.publisher] ?? [],
          characters: p[PersonRole.character] ?? [],
          coverArtists: p[PersonRole.coverArtist] ?? [],
          pencillers: p[PersonRole.penciller] ?? [],
          inkers: p[PersonRole.inker] ?? [],
          imprints: p[PersonRole.imprint] ?? [],
          colorists: p[PersonRole.colorist] ?? [],
          letterers: p[PersonRole.letterer] ?? [],
          editors: p[PersonRole.editor] ?? [],
          translators: p[PersonRole.translator] ?? [],
          teams: p[PersonRole.team] ?? [],
          locations: p[PersonRole.location] ?? [],
        );
      });
    });
  }

  /// Get the list of series ids without metadata
  Future<List<int>> getMissingSeriesIds() async {
    final query =
        select(series).join([
          leftOuterJoin(
            seriesMetadata,
            seriesMetadata.seriesId.equalsExp(series.id),
          ),
        ])..where(
          seriesMetadata.seriesId.isNull() |
              seriesMetadata.lastUpdated.isSmallerThan(series.lastChapterAdded),
        );

    return await query.map((row) => row.readTable(series).id).get();
  }

  /// Upsert batch of [SeriesMetadataCompanions]
  Future<void> upsertMetadataBatch(
    Iterable<SeriesMetadataCompanions> metadata,
  ) async {
    final items = metadata.toList();
    final meta = items.map((m) => m.metadata);
    final metadataIds = items.map((m) => m.metadata.id.value);
    final ps = items.expand(
      (m) => [
        ...m.writers,
        ...m.coverArtists,
        ...m.publishers,
        ...m.characters,
        ...m.pencillers,
        ...m.inkers,
        ...m.imprints,
        ...m.colorists,
        ...m.letterers,
        ...m.editors,
        ...m.translators,
        ...m.teams,
        ...m.locations,
      ],
    );
    final peopleLinks = items.expand((m) => m.seriesPeopleRoles);
    final gs = items.expand((m) => m.genres);
    final genresLinks = items.expand((m) => m.seriesGenres);
    final ts = items.expand((m) => m.tags);
    final tagsLinks = items.expand((m) => m.seriesTags);

    await batch((batch) {
      batch.deleteWhere(
        seriesPeopleRoles,
        (t) => t.seriesMetadataId.isIn(metadataIds),
      );
      batch.deleteWhere(
        seriesGenres,
        (t) => t.seriesMetadataId.isIn(metadataIds),
      );
      batch.deleteWhere(
        seriesTags,
        (t) => t.seriesMetadataId.isIn(metadataIds),
      );
      batch.insertAllOnConflictUpdate(seriesMetadata, meta);
      batch.insertAllOnConflictUpdate(people, ps);
      batch.insertAllOnConflictUpdate(seriesPeopleRoles, peopleLinks);
      batch.insertAllOnConflictUpdate(genres, gs);
      batch.insertAllOnConflictUpdate(seriesGenres, genresLinks);
      batch.insertAllOnConflictUpdate(tags, ts);
      batch.insertAllOnConflictUpdate(seriesTags, tagsLinks);
    });
  }

  Future<void> upsertMetadataAndDetails({
    required SeriesMetadataCompanions metadata,
    required SeriesDetailCompanions details,
  }) async {
    await transaction(() async {
      await upsertMetadataBatch([metadata]);
      await attachedDatabase.seriesDao.mergeSeriesDetails(details);
    });
  }
}

class const SeriesMetadataWithRelations({
  required final SeriesMetadataData metadata,
  required final List<PeopleData> writers,
  required final List<PeopleData> coverArtists,
  required final List<PeopleData> publishers,
  required final List<PeopleData> characters,
  required final List<PeopleData> pencillers,
  required final List<PeopleData> inkers,
  required final List<PeopleData> imprints,
  required final List<PeopleData> colorists,
  required final List<PeopleData> letterers,
  required final List<PeopleData> editors,
  required final List<PeopleData> translators,
  required final List<PeopleData> teams,
  required final List<PeopleData> locations,
  required final List<Genre> genres,
  required final List<Tag> tags,
});

class const SeriesMetadataCompanions({
  required final SeriesMetadataCompanion metadata,
  required final Iterable<GenresCompanion> genres,
  required final Iterable<PeopleCompanion> writers,
  required final Iterable<PeopleCompanion> coverArtists,
  required final Iterable<PeopleCompanion> publishers,
  required final Iterable<PeopleCompanion> characters,
  required final Iterable<PeopleCompanion> pencillers,
  required final Iterable<PeopleCompanion> inkers,
  required final Iterable<PeopleCompanion> imprints,
  required final Iterable<PeopleCompanion> colorists,
  required final Iterable<PeopleCompanion> letterers,
  required final Iterable<PeopleCompanion> editors,
  required final Iterable<PeopleCompanion> translators,
  required final Iterable<PeopleCompanion> teams,
  required final Iterable<PeopleCompanion> locations,
  required final Iterable<TagsCompanion> tags,
}) {
  SeriesPeopleRolesCompanion _mappingWithRole(
    PeopleCompanion person,
    PersonRole role,
  ) {
    return SeriesPeopleRolesCompanion.insert(
      seriesMetadataId: metadata.id.value,
      personId: person.id.value,
      role: role,
    );
  }
}

extension on SeriesMetadataCompanions {
  Iterable<SeriesPeopleRolesCompanion> get seriesPeopleRoles {
    return [
      ...writers.map((p) => _mappingWithRole(p, .writer)),
      ...coverArtists.map((p) => _mappingWithRole(p, .coverArtist)),
      ...publishers.map((p) => _mappingWithRole(p, .publisher)),
      ...characters.map((p) => _mappingWithRole(p, .character)),
      ...pencillers.map((p) => _mappingWithRole(p, .penciller)),
      ...inkers.map((p) => _mappingWithRole(p, .inker)),
      ...imprints.map((p) => _mappingWithRole(p, .imprint)),
      ...colorists.map((p) => _mappingWithRole(p, .colorist)),
      ...letterers.map((p) => _mappingWithRole(p, .letterer)),
      ...editors.map((p) => _mappingWithRole(p, .editor)),
      ...translators.map((p) => _mappingWithRole(p, .translator)),
      ...teams.map((p) => _mappingWithRole(p, .team)),
      ...locations.map((p) => _mappingWithRole(p, .location)),
    ];
  }

  Iterable<SeriesGenresCompanion> get seriesGenres {
    return genres.map(
      (g) => SeriesGenresCompanion.insert(
        seriesMetadataId: metadata.id.value,
        genreId: g.id.value,
      ),
    );
  }

  Iterable<SeriesTagsCompanion> get seriesTags {
    return tags.map(
      (t) => SeriesTagsCompanion.insert(
        seriesMetadataId: metadata.id.value,
        tagId: t.id.value,
      ),
    );
  }
}
