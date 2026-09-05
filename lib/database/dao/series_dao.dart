import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/on_deck_removal.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/server_settings.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/database/tables/want_to_read.dart';
import 'package:kover/utils/chunked_operation.dart';
import 'package:kover/utils/data_constants.dart';
import 'package:rxdart/rxdart.dart';

part 'series_dao.g.dart';

@DriftAccessor(
  tables: [
    Series,
    SeriesCovers,
    Volumes,
    Chapters,
    ReadingProgress,
    WantToRead,
    ServerSettings,
    Libraries,
    OnDeckRemoval,
    People,
    Genres,
    Tags,
    ChapterPeopleRoles,
    ChapterGenres,
    ChapterTags,
  ],
)
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.attachedDatabase);

  /// Watch series [seriesId]
  Stream<SeriesData?> watchSeries(int seriesId) {
    return managers.series
        .filter((s) => s.id(seriesId))
        .watchSingleOrNull(distinct: true);
  }

  /// Search series by [query].
  Future<List<SeriesData>> searchSeries(String query) async {
    final q = managers.series
        .filter((f) => f.libraryId.includeInSearch(true))
        .filter(
          (f) =>
              f.name.contains(query) |
              f.sortName.contains(query) |
              f.localizedName.contains(query) |
              f.originalName.contains(query),
        )
        .orderBy((o) => o.sortName.asc());

    return await q.get();
  }

  /// Filter series by [query]. Optionally filter by [libraryId]
  Future<List<SeriesData>> filterSeries(
    String query, {
    int? libraryId,
    int? collectionId,
    bool orderByName = false,
    bool orderByRecentlyAdded = false,
    bool orderByRecentlyUpdated = false,
    bool ascending = true,
  }) async {
    final q = select(series)
      ..where(
        (table) =>
            table.name.contains(query) |
            table.sortName.contains(query) |
            table.localizedName.contains(query) |
            table.originalName.contains(query),
      );

    if (libraryId != null) {
      q.where((table) => table.libraryId.equals(libraryId));
    }

    if (collectionId != null) {
      q.where(
        (table) => table.id.isInQuery(
          selectOnly(db.collectionSeries)
            ..addColumns([db.collectionSeries.seriesId])
            ..where(db.collectionSeries.collectionId.equals(collectionId)),
        ),
      );
    }

    q.orderBy([
      if (orderByName)
        (table) => OrderingTerm(
          expression: series.sortName,
          mode: ascending ? .asc : .desc,
        ),

      if (orderByRecentlyAdded)
        (table) => OrderingTerm(
          expression: series.created,
          mode: ascending ? .asc : .desc,
        ),

      if (orderByRecentlyUpdated)
        (table) => OrderingTerm(
          expression: series.lastChapterAdded,
          mode: ascending ? .asc : .desc,
        ),
    ]);

    return await q.get();
  }

  /// Watch series for chapter [chapterId]. Emits null when the chapter does not exist
  Stream<SeriesData?> watchSeriesForChapter(int chapterId) {
    return managers.chapters
        .withReferences()
        .filter((f) => f.id(chapterId))
        .asyncMap((res) async {
          final (_, refs) = res;
          return await refs.seriesId.getSingle(distinct: true);
        })
        .watchSingleOrNull();
  }

  /// Get [SingleOrNullSelectable] cover for series [seriesId]
  SingleOrNullSelectable<SeriesCover?> seriesCover({required int seriesId}) {
    return managers.seriesCovers.filter((f) => f.seriesId.id(seriesId));
  }

  /// Watch series details for series [seriesId]
  Stream<SeriesDetailWithRelations> watchSeriesDetail(int seriesId) {
    final volumesStream = managers.volumes
        .filter((f) => f.seriesId.id(seriesId))
        .orderBy((o) => o.minNumber.asc() & o.maxNumber.asc())
        .withReferences((fetch) => fetch(chaptersRefs: true))
        .map(
          (m) {
            final chapters = m.$2.chaptersRefs.prefetchedData ?? [];
            chapters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            return VolumeWithRelations(volume: m.$1, chapters: chapters);
          },
        )
        .watch();

    final baseChaptersManager = managers.chapters
        .filter((f) => f.seriesId.id(seriesId))
        .orderBy(
          (o) => o.volumeId.minNumber.asc() & o.sortOrder.asc(),
        );

    final chaptersStream = baseChaptersManager
        .filter(
          (f) => f.minNumber.isBiggerThan(
            DataConstants.singleVolumeChapterMinNumber,
          ),
        )
        .watch();

    final specialsStream = baseChaptersManager
        .filter((f) => f.isSpecial.equals(true))
        .watch();

    final storylineStream = baseChaptersManager
        .filter((f) => f.isStoryline.equals(true))
        .watch();

    final unreadChaptersStream = unreadChapters(
      seriesId: seriesId,
    ).watch();

    final unreadVolumesStream = unreadVolumes(seriesId: seriesId).watch();

    return Rx.combineLatest6(
      volumesStream,
      chaptersStream,
      specialsStream,
      storylineStream,
      unreadChaptersStream,
      unreadVolumesStream,
      (vList, cList, sList, slList, uList, uvList) => SeriesDetailWithRelations(
        volumes: vList,
        chapters: cList,
        storylineChapters: slList,
        specials: sList,
        unreadChapters: uList,
        unreadVolumes: uvList,
      ),
    );
  }

  /// Watch pages read for series [seriesId]
  Stream<int?> watchPagesRead({required int seriesId}) {
    final pagesReadSum = readingProgress.pagesRead.sum();

    final query = selectOnly(readingProgress)
      ..addColumns([pagesReadSum])
      ..where(readingProgress.seriesId.equals(seriesId))
      ..groupBy([readingProgress.seriesId]);

    return query.watchSingleOrNull().map((row) => row?.read(pagesReadSum));
  }

  /// Get all series stored in the database, optionally filtering by [libraryId]
  MultiSelectable<SeriesData> allSeries({
    int? libraryId,
    int? collectionId,
    bool orderByName = false,
    bool orderByRecentlyAdded = false,
    bool orderByRecentlyUpdated = false,
    bool ascending = true,
  }) {
    final query = select(series);

    if (libraryId != null) {
      query.where((table) => table.libraryId.equals(libraryId));
    }

    if (collectionId != null) {
      query.where(
        (table) => table.id.isInQuery(
          selectOnly(db.collectionSeries)
            ..addColumns([db.collectionSeries.seriesId])
            ..where(db.collectionSeries.collectionId.equals(collectionId)),
        ),
      );
    }

    query.orderBy([
      if (orderByName)
        (table) => OrderingTerm(
          expression: table.sortName,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),

      if (orderByRecentlyAdded)
        (table) => OrderingTerm(
          expression: table.created,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),

      if (orderByRecentlyUpdated)
        (table) => OrderingTerm(
          expression: table.lastChapterAdded,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),
    ]);

    return query;
  }

  /// Get all chapters for series [seriesId]
  MultiSelectable<Chapter> allChapters({required int seriesId}) {
    return managers.chapters
        .filter((f) => f.seriesId.id(seriesId))
        .orderBy((o) => o.sortOrder.asc());
  }

  /// Get all unread chapters for series [seriesId].
  /// Unread chapters are all chapters with either no progress, or not completely read
  MultiSelectable<Chapter> unreadChapters({required int seriesId}) {
    final query =
        select(chapters).join([
            leftOuterJoin(
              readingProgress,
              readingProgress.chapterId.equalsExp(chapters.id),
            ),
          ])
          ..where(
            chapters.minNumber.isBiggerThanValue(
                  DataConstants.singleVolumeChapterMinNumber,
                ) &
                chapters.seriesId.equals(seriesId) &
                (readingProgress.chapterId.isNull() |
                    readingProgress.pagesRead.isSmallerThan(chapters.pages)),
          )
          ..orderBy([OrderingTerm.asc(chapters.sortOrder)]);

    return query.map((res) => res.readTable(chapters));
  }

  /// Get all unread volumes for series [seriesId].
  /// Unread volumes are volumes with at least one chapter with either no progress,
  /// or not completely read
  MultiSelectable<VolumeWithRelations> unreadVolumes({required int seriesId}) {
    final query =
        select(volumes).join([
            innerJoin(chapters, chapters.volumeId.equalsExp(volumes.id)),
            leftOuterJoin(
              readingProgress,
              readingProgress.chapterId.equalsExp(chapters.id),
            ),
          ])
          ..where(
            volumes.seriesId.equals(seriesId) &
                (readingProgress.chapterId.isNull() |
                    readingProgress.pagesRead.isSmallerThan(chapters.pages)),
          )
          ..groupBy([volumes.id])
          ..orderBy([OrderingTerm.asc(volumes.minNumber)]);

    return query
        .map((res) => res.readTable(volumes))
        .asyncMap(
          (v) async => VolumeWithRelations(
            volume: v,
            chapters: await managers.chapters
                .filter(
                  (f) => f.volumeId.id(v.id),
                )
                .orderBy((o) => o.sortOrder.asc())
                .get(),
          ),
        );
  }

  /// A series is on deck when:
  /// - The user has read some pages but not all (partially read)
  /// - AND either:
  ///   - The last reading activity was within [ServerSettings.onDeckProgressDays] days, OR
  ///   - A chapter was added within [ServerSettings.onDeckUpdateDays] days
  ///
  /// Ordered by most recent reading activity, then most recently updated.
  JoinedSelectStatement _buildOnDeckQuery({
    required int progressDays,
    required int updateDays,
  }) {
    final totalPagesRead = readingProgress.pagesRead.sum();
    final latestReadDate = readingProgress.lastModified.max();

    final cutoffProgress = DateTime.now().subtract(
      Duration(days: progressDays),
    );
    final cutoffLastAdded = DateTime.now().subtract(Duration(days: updateDays));

    return select(series).join([
        innerJoin(
          readingProgress,
          readingProgress.seriesId.equalsExp(series.id),
        ),
        innerJoin(
          libraries,
          libraries.id.equalsExp(series.libraryId),
        ),
        leftOuterJoin(
          onDeckRemoval,
          onDeckRemoval.seriesId.equalsExp(series.id),
        ),
      ])
      ..where(
        libraries.includeInDashboard.equals(true) &
            onDeckRemoval.seriesId.isNull(),
      )
      ..addColumns([totalPagesRead, latestReadDate])
      ..groupBy(
        [series.id],
        having:
            totalPagesRead.isBiggerThanValue(0) &
            totalPagesRead.isSmallerThan(series.pages) &
            (latestReadDate.isBiggerOrEqualValue(cutoffProgress) |
                series.lastChapterAdded.isBiggerOrEqualValue(
                  cutoffLastAdded,
                )),
      )
      ..orderBy([
        OrderingTerm.desc(latestReadDate),
        OrderingTerm.desc(series.lastChapterAdded),
      ]);
  }

  /// Watch series on deck.
  Stream<List<SeriesData>> watchOnDeck() {
    return managers.serverSettings
        .filter((f) => f.key.equals(DataConstants.serverSettingsKey))
        .watchSingleOrNull()
        .distinct()
        .switchMap((setting) {
          final progressDays =
              setting?.onDeckProgressDays ?? DataConstants.onDeckProgressDays;
          final updateDays =
              setting?.onDeckUpdateDays ?? DataConstants.onDeckUpdateDays;

          return _buildOnDeckQuery(
            progressDays: progressDays,
            updateDays: updateDays,
          ).watch().map(
            (rows) => rows.map((row) => row.readTable(series)).toList(),
          );
        });
  }

  /// Get series on deck.
  Future<List<SeriesData>> getOnDeck() async {
    final setting = await managers.serverSettings
        .filter((f) => f.key.equals(DataConstants.serverSettingsKey))
        .getSingleOrNull();

    final progressDays =
        setting?.onDeckProgressDays ?? DataConstants.onDeckProgressDays;
    final updateDays =
        setting?.onDeckUpdateDays ?? DataConstants.onDeckUpdateDays;

    return await _buildOnDeckQuery(
          progressDays: progressDays,
          updateDays: updateDays,
        )
        .map(
          (row) => row.readTable(series),
        )
        .get();
  }

  /// Watch recently updated series
  Stream<List<SeriesData>> watchRecentlyUpdated() {
    return managers.series
        .filter((f) => f.isRecentlyUpdated(true))
        .orderBy((o) => o.lastChapterAdded.desc())
        .watch();
  }

  /// Watch recently added series
  Stream<List<SeriesData>> watchRecentlyAdded() {
    return managers.series
        .filter((f) => f.isRecentlyAdded(true))
        .orderBy((o) => o.created.desc())
        .watch();
  }

  /// Watch whether [seriesId] is want-to-read
  Stream<bool> watchWantToRead(int seriesId) {
    return managers.wantToRead
        .filter((f) => f.seriesId.id(seriesId) & f.isWantToRead(true))
        .watchSingleOrNull()
        .map((i) => i != null && i.isWantToRead);
  }

  /// Watch the want-to-read list
  Stream<List<SeriesData>> watchWantToReadList() {
    return (select(wantToRead).join([
          innerJoin(series, series.id.equalsExp(wantToRead.seriesId)),
        ])..where(wantToRead.isWantToRead.equals(true)))
        .map((res) => res.readTable(series))
        .watch();
  }

  /// Get all locally modified want-to-read entries
  Future<List<WantToReadData>> getDirtyWantToRead() async {
    return await managers.wantToRead.filter((f) => f.dirty(true)).get();
  }

  /// Get the list of series ids without a cover
  Future<List<int>> getMissingCovers() async {
    final query = select(series).join([
      leftOuterJoin(seriesCovers, seriesCovers.seriesId.equalsExp(series.id)),
    ]);

    query.where(seriesCovers.seriesId.isNull());

    return await query.map((row) => row.readTable(series).id).get();
  }

  /// Get the list of series ids that have never been synced or that have new
  /// remote progress or chapters since their last sync.
  Future<List<int>> getOutdatedDetailsSeriesIds() async {
    final query = selectOnly(series, distinct: true)
      ..addColumns([series.id])
      ..where(
        series.lastSynced.isNull() |
            series.remoteLastRead.isBiggerThan(series.lastSynced) |
            series.lastChapterAdded.isBiggerThan(series.lastSynced),
      );

    return await query.map((row) => row.read(series.id)!).get();
  }

  /// Reconcile the series table with the provided [entries]. Deletes any series
  /// not present in [entries] and upserts the provided entries.
  Future<void> reconcileSeriesBatch(Iterable<SeriesCompanion> entries) async {
    final ids = entries.map((e) => e.id.value).toSet();

    await transaction(() async {
      await chunkedOperation(
        items: ids,
        operation: (b) async {
          await (delete(series)..where((tbl) => tbl.id.isNotIn(b))).go();
        },
      );
      await upsertSeriesBatch(entries);
    });
  }

  /// Upsert a batch of series
  Future<void> upsertSeriesBatch(Iterable<SeriesCompanion> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(series, entries);
    });
  }

  /// Upsert [detailEntries]
  /// and mark their series as synced. Used to fetch details for series that
  /// have new remote progress or chapters since their last sync.
  Future<void> upsertDetailsBatch(
    Iterable<SeriesDetailCompanions> entries,
  ) async {
    if (entries.isEmpty) return;

    final ids = entries.map((d) => d.seriesId).toSet();

    await transaction(() async {
      await _upsertDetailEntries(entries);
      await chunkedOperation(
        items: ids,
        operation: (b) async {
          await (update(series)..where((t) => t.id.isIn(b))).write(
            SeriesCompanion(lastSynced: Value(DateTime.timestamp())),
          );
        },
      );
    });
  }

  Future<void> _upsertDetailEntries(
    Iterable<SeriesDetailCompanions> detailEntries,
  ) async {
    final volumesBySeries = <int, Iterable<int>>{};
    final chaptersBySeries = <int, Iterable<int>>{};

    final allVolumes = <VolumesCompanion>{};
    final allChapters = <ChaptersCompanion>{};
    final allPeople = <PeopleCompanion>{};
    final allGenres = <GenresCompanion>{};
    final allTags = <TagsCompanion>{};
    final allRoleLinks = <ChapterPeopleRolesCompanion>{};
    final allGenreLinks = <ChapterGenresCompanion>{};
    final allTagLinks = <ChapterTagsCompanion>{};

    for (final detail in detailEntries) {
      final chapters = {
        ...detail.volumes.map((volume) => volume.chapters).expand((c) => c),
        ...detail.storyline,
        ...detail.specials,
        ...detail.chapters,
      };

      volumesBySeries[detail.seriesId] = detail.volumes.map(
        (v) => v.volume.id.value,
      );
      chaptersBySeries[detail.seriesId] = chapters.map(
        (c) => c.chapter.id.value,
      );

      allVolumes.addAll(detail.volumes.map((v) => v.volume));
      allChapters.addAll(chapters.map((c) => c.chapter));

      for (final c in chapters) {
        allPeople.addAll([
          ...c.writers,
          ...c.coverArtists,
          ...c.publishers,
          ...c.characters,
          ...c.pencillers,
          ...c.inkers,
          ...c.imprints,
          ...c.colorists,
          ...c.letterers,
          ...c.editors,
          ...c.translators,
          ...c.teams,
          ...c.locations,
        ]);
        allGenres.addAll(c.genres);
        allTags.addAll(c.tags);
      }

      allRoleLinks.addAll(chapters.expand((c) => c.chapterPeopleRoles));
      allGenreLinks.addAll(chapters.expand((c) => c.chapterGenres));
      allTagLinks.addAll(chapters.expand((c) => c.chapterTags));
    }

    await batch((batch) {
      for (final entry in volumesBySeries.entries) {
        if (entry.value.isEmpty) continue;
        batch.deleteWhere(
          volumes,
          (t) => t.seriesId.equals(entry.key) & t.id.isNotIn(entry.value),
        );
      }
      batch.insertAllOnConflictUpdate(volumes, allVolumes);
    });

    await batch((batch) {
      for (final entry in chaptersBySeries.entries) {
        if (entry.value.isEmpty) continue;
        batch.deleteWhere(
          chapters,
          (t) => t.seriesId.equals(entry.key) & t.id.isNotIn(entry.value),
        );
      }
      batch.insertAllOnConflictUpdate(chapters, allChapters);
    });

    await batch((batch) {
      chunkedOperation(
        items: allChapters.map((c) => c.id.value),
        operation: (chunk) {
          batch.deleteWhere(
            chapterPeopleRoles,
            (t) => t.chapterId.isIn(chunk),
          );
          batch.deleteWhere(chapterGenres, (t) => t.chapterId.isIn(chunk));
          batch.deleteWhere(chapterTags, (t) => t.chapterId.isIn(chunk));
        },
      );
      batch.insertAllOnConflictUpdate(people, allPeople);
      batch.insertAllOnConflictUpdate(genres, allGenres);
      batch.insertAllOnConflictUpdate(tags, allTags);
      batch.insertAllOnConflictUpdate(chapterPeopleRoles, allRoleLinks);
      batch.insertAllOnConflictUpdate(chapterGenres, allGenreLinks);
      batch.insertAllOnConflictUpdate(chapterTags, allTagLinks);
    });
  }

  /// Clear all recently updated and upsert provided [entries]
  Future<void> upsertRecentlyUpdated(Iterable<SeriesCompanion> entries) async {
    await transaction(() async {
      await clearIsRecentlyUpdated();
      await batch((batch) {
        for (final entry in entries) {
          batch.update(
            series,
            entry,
            where: (tbl) => tbl.id.equals(entry.id.value),
          );
        }
      });
    });
  }

  /// Clear all recently added and upsert provided [entries]
  Future<void> upsertRecentlyAdded(Iterable<SeriesCompanion> entries) async {
    await transaction(() async {
      await clearIsRecentlyAdded();
      await upsertSeriesBatch(entries);
    });
  }

  /// Upsert want-to-read entry
  Future<void> upsertWantToRead(WantToReadCompanion entry) async {
    await into(wantToRead).insertOnConflictUpdate(entry);
  }

  /// Upsert the provided [entries] batch of series as want-to-read
  Future<void> upsertWantToReadFromSeriesBatch(
    Iterable<SeriesCompanion> entries,
  ) async {
    final wantToReads = entries.map(
      (s) => WantToReadCompanion(seriesId: s.id),
    );
    await transaction(() async {
      await clearWantToRead();
      await batch(
        (batch) {
          batch.insertAllOnConflictUpdate(series, entries);
          batch.insertAllOnConflictUpdate(wantToRead, wantToReads);
        },
      );
    });
  }

  /// Remove [seriesId] from want-to-read. Sets the entry as dirty.
  Future<void> removeWantToRead({required int seriesId}) async {
    await (update(
      wantToRead,
    )..where((tbl) => tbl.seriesId.equals(seriesId))).write(
      const WantToReadCompanion(isWantToRead: Value(false), dirty: Value(true)),
    );
  }

  /// Upsert a series cover
  Future<void> upsertSeriesCover(SeriesCoversCompanion cover) async {
    await into(seriesCovers).insertOnConflictUpdate(cover);
  }

  /// Upsert multiple series covers in a single batch to avoid per-insert
  /// [notifyUpdates] cascades that can block the main thread.
  Future<void> upsertSeriesCoversBatch(
    Iterable<SeriesCoversCompanion> covers,
  ) async {
    if (covers.isEmpty) return;

    await batch((b) => b.insertAllOnConflictUpdate(seriesCovers, covers));
  }

  /// Set all isRecentlyUpdated flags to false
  Future<void> clearIsRecentlyUpdated() async {
    await (update(series)..where((row) => row.isRecentlyUpdated)).write(
      const SeriesCompanion(isRecentlyUpdated: Value(false)),
    );
  }

  /// Clear all isRecentlyAdded flags
  Future<void> clearIsRecentlyAdded() async {
    await (update(series)..where((row) => row.isRecentlyAdded)).write(
      const SeriesCompanion(isRecentlyAdded: Value(false)),
    );
  }

  Future<List<OnDeckRemovalData>> getDirtyOnDeckRemovalSeriesIds() async {
    return await managers.onDeckRemoval.filter((f) => f.dirty(true)).get();
  }

  /// Clear the want to read list
  Future<void> clearWantToRead() async {
    await delete(wantToRead).go();
  }

  /// Clear dirty flags for OnDeckRemoval entries for series [seriesIds]
  Future<void> clearDirtyOnDeckRemovalForSeries(Iterable<int> seriesIds) async {
    await transaction(() async {
      await chunkedOperation(
        items: seriesIds,
        operation: (batch) async {
          await (update(onDeckRemoval)
                ..where((tbl) => tbl.seriesId.isIn(batch)))
              .write(const OnDeckRemovalCompanion(dirty: Value(false)));
        },
      );
    });
  }

  /// Remove on deck removal entry for series [seriesId] if present.
  Future<void> clearOnDeckRemovalForSeries(int seriesId) async {
    await managers.onDeckRemoval
        .filter((f) => f.seriesId.id(seriesId))
        .delete();
  }

  /// Remove batch from on deck removal table for series [seriesIds] if present
  /// and clean.
  Future<void> clearOnDeckRemovalForSeriesBatch(
    Iterable<int> seriesIds, {
    bool cleanOnly = true,
  }) async {
    final query = delete(onDeckRemoval)
      ..where((tbl) => tbl.seriesId.isIn(seriesIds));

    if (cleanOnly) {
      query.where((tbl) => tbl.dirty.equals(false));
    }

    await query.go();
  }

  Future<void> upsertOnDeckRemovalBatch(
    Iterable<OnDeckRemovalCompanion> entries,
  ) async {
    await batch((b) => b.insertAllOnConflictUpdate(onDeckRemoval, entries));
  }
}

class SeriesDetailWithRelations {
  final List<VolumeWithRelations> volumes;
  final List<Chapter> specials;
  final List<Chapter> chapters;
  final List<Chapter> storylineChapters;
  final List<Chapter> unreadChapters;
  final List<VolumeWithRelations> unreadVolumes;

  const SeriesDetailWithRelations({
    required this.volumes,
    required this.specials,
    required this.chapters,
    required this.storylineChapters,
    required this.unreadChapters,
    required this.unreadVolumes,
  });
}

class const SeriesDetailCompanions({
  required final int seriesId,
  required final Iterable<ChapterWithRelationsCompanion> storyline,
  required final Iterable<ChapterWithRelationsCompanion> specials,
  required final Iterable<ChapterWithRelationsCompanion> chapters,
  required final Iterable<VolumeWithChaptersCompanion> volumes,
});
