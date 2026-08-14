import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/models/enums/person_role.dart';

part 'chapters_dao.g.dart';

@DriftAccessor(
  tables: [
    Chapters,
    ChapterCovers,
    ReadingProgress,
    Series,
    Libraries,
  ],
)
class ChaptersDao extends DatabaseAccessor<AppDatabase>
    with _$ChaptersDaoMixin {
  ChaptersDao(super.attachedDatabase);

  /// Get [SingleSelectable] for chapter [chapterId]
  SingleSelectable<Chapter> chapter(int chapterId) {
    return managers.chapters.filter((f) => f.id.equals(chapterId));
  }

  /// Search chapters by [query]. Optionally filter by [volumeId] and/or [seriesId]
  Future<List<Chapter>> searchChapters(
    String query, {
    int? volumeId,
    int? seriesId,
  }) {
    final q = managers.chapters
        .filter((f) => f.seriesId.libraryId.includeInSearch(true))
        .filter(
          (f) => f.titleName.contains(query) | f.titleName.contains(query),
        );

    if (volumeId != null) {
      q.filter((f) => f.volumeId.id(volumeId));
    }

    if (seriesId != null) {
      q.filter((f) => f.seriesId.id(seriesId));
    }

    q.orderBy(
      (o) =>
          o.volumeId.minNumber.asc() &
          o.sortOrder.asc() &
          o.seriesId.id.asc() &
          o.titleName.asc() &
          o.title.asc(),
    );

    return q.get();
  }

  /// Watch pages read for chapter [chapterId]
  Stream<int?> watchPagesRead({required int chapterId}) {
    final query = selectOnly(readingProgress)
      ..where(readingProgress.chapterId.equals(chapterId))
      ..addColumns([readingProgress.pagesRead]);

    return query.watchSingleOrNull().map(
      (row) => row?.read(readingProgress.pagesRead),
    );
  }

  /// Get [SingleOrNullSelectable] cover for chapter [chapterId]. Returns null if no cover is present
  SingleOrNullSelectable<ChapterCover?> chapterCover({required int chapterId}) {
    return managers.chapterCovers.filter((f) => f.chapterId.id(chapterId));
  }

  /// Get the list chapter ids missing a cover
  Future<List<int>> getMissingCovers() async {
    final query = select(chapters).join([
      leftOuterJoin(
        chapterCovers,
        chapterCovers.chapterId.equalsExp(chapters.id),
      ),
    ]);

    query.where(chapterCovers.chapterId.isNull());

    return await query.map((row) => row.readTable(chapters).id).get();
  }

  /// Upsert a chapter cover
  Future<void> upsertChapterCover(ChapterCoversCompanion cover) async {
    await into(chapterCovers).insertOnConflictUpdate(cover);
  }

  /// Upsert multiple chapter covers in a single batch to avoid per-insert
  /// [notifyUpdates] cascades that can block the main thread.
  Future<void> upsertChapterCoversBatch(
    Iterable<ChapterCoversCompanion> covers,
  ) async {
    if (covers.isEmpty) return;

    await batch((b) => b.insertAllOnConflictUpdate(chapterCovers, covers));
  }
}

class const ChapterWithRelationsCompanion({
  required final ChaptersCompanion chapter,
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
  required final Iterable<GenresCompanion> genres,
  required final Iterable<TagsCompanion> tags,
}) {
  ChapterPeopleRolesCompanion mappingWithRole(
    PeopleCompanion person,
    PersonRole role,
  ) {
    return ChapterPeopleRolesCompanion.insert(
      chapterId: chapter.id.value,
      personId: person.id.value,
      role: role,
    );
  }

  Iterable<ChapterPeopleRolesCompanion> get chapterPeopleRoles => [
    ...writers.map((p) => mappingWithRole(p, .writer)),
    ...coverArtists.map((p) => mappingWithRole(p, .coverArtist)),
    ...publishers.map((p) => mappingWithRole(p, .publisher)),
    ...characters.map((p) => mappingWithRole(p, .character)),
    ...pencillers.map((p) => mappingWithRole(p, .penciller)),
    ...inkers.map((p) => mappingWithRole(p, .inker)),
    ...imprints.map((p) => mappingWithRole(p, .imprint)),
    ...colorists.map((p) => mappingWithRole(p, .colorist)),
    ...letterers.map((p) => mappingWithRole(p, .letterer)),
    ...editors.map((p) => mappingWithRole(p, .editor)),
    ...translators.map((p) => mappingWithRole(p, .translator)),
    ...teams.map((p) => mappingWithRole(p, .team)),
    ...locations.map((p) => mappingWithRole(p, .location)),
  ];

  Iterable<ChapterGenresCompanion> get chapterGenres {
    return genres.map(
      (g) => ChapterGenresCompanion.insert(
        chapterId: chapter.id.value,
        genreId: g.id.value,
      ),
    );
  }

  Iterable<ChapterTagsCompanion> get chapterTags {
    return tags.map(
      (t) => ChapterTagsCompanion.insert(
        chapterId: chapter.id.value,
        tagId: t.id.value,
      ),
    );
  }

  ChapterWithRelationsCompanion replace({
    Value<int>? seriesId,
    Value<bool>? isStoryline,
    Value<bool>? isSpecial,
    Value<int>? volumeId,
  }) {
    var next = chapter;
    if (seriesId != null ||
        isStoryline != null ||
        isSpecial != null ||
        volumeId != null) {
      next = next.copyWith(
        seriesId: seriesId,
        isStoryline: isStoryline,
        isSpecial: isSpecial,
        volumeId: volumeId,
      );
    }
    return ChapterWithRelationsCompanion(
      chapter: next,
      writers: writers,
      coverArtists: coverArtists,
      publishers: publishers,
      characters: characters,
      pencillers: pencillers,
      inkers: inkers,
      imprints: imprints,
      colorists: colorists,
      letterers: letterers,
      editors: editors,
      translators: translators,
      teams: teams,
      locations: locations,
      genres: genres,
      tags: tags,
    );
  }
}
