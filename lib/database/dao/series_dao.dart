import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/server_settings.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/database/tables/want_to_read.dart';
import 'package:kover/utils/data_constants.dart';
import 'package:kover/utils/logging.dart';
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
  ],
)
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.attachedDatabase);

  /// Watch series [seriesId]
  Stream<SeriesData> watchSeries(int seriesId) {
    return managers.series
        .filter((s) => s.id(seriesId))
        .watchSingle(distinct: true);
  }

  /// Search series by [query]. Optionally filter by [libraryId]
  Future<List<SeriesData>> searchSeries(
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
          expression: table.sortName,
          mode: ascending ? .asc : .desc,
        ),

      if (orderByRecentlyAdded)
        (table) => OrderingTerm(
          expression: table.created,
          mode: ascending ? .asc : .desc,
        ),

      if (orderByRecentlyUpdated)
        (table) => OrderingTerm(
          expression: table.lastChapterAdded,
          mode: ascending ? .asc : .desc,
        ),
    ]);

    return await q.get();
  }

  Stream<SeriesData> watchSeriesForChapter(int chapterId) {
    return managers.chapters
        .withReferences()
        .filter((f) => f.id(chapterId))
        .asyncMap((res) async {
          final (_, refs) = res;
          return await refs.seriesId.getSingle(distinct: true);
        })
        .watchSingle();
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
          (m) => VolumeWithRelations(
            volume: m.$1,
            chapters: m.$2.chaptersRefs.prefetchedData ?? [],
          ),
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
                .get(),
          ),
        );
  }

  /// Watch series on deck.
  ///
  /// A series is on deck when:
  /// - The user has read some pages but not all (partially read)
  /// - AND either:
  ///   - The last reading activity was within [ServerSettings.onDeckProgressDays] days, OR
  ///   - A chapter was added within [ServerSettings.onDeckUpdateDays] days
  ///
  /// Ordered by most recent reading activity, then most recently updated.
  Stream<List<SeriesData>> watchOnDeck() async* {
    final totalPagesRead = readingProgress.pagesRead.sum();
    final latestReadDate = readingProgress.lastModified.max();

    yield* managers.serverSettings
        .filter((f) => f.key.equals(DataConstants.serverSettingsKey))
        .watchSingleOrNull()
        .switchMap((setting) {
          final progressDays =
              setting?.onDeckProgressDays ?? DataConstants.onDeckProgressDays;
          final updateDays =
              setting?.onDeckUpdateDays ?? DataConstants.onDeckUpdateDays;

          final cutoffProgress = DateTime.now().subtract(
            Duration(days: progressDays),
          );
          final cutoffLastAdded = DateTime.now().subtract(
            Duration(days: updateDays),
          );

          final query =
              select(series).join([
                  innerJoin(
                    readingProgress,
                    readingProgress.seriesId.equalsExp(series.id),
                  ),
                ])
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

          return query.map((row) => row.readTable(series)).watch();
        });
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

  /// Upsert a batch of series
  Future<void> upsertSeriesBatch(Iterable<SeriesCompanion> entries) async {
    log.d('upserting series batch with ${entries.length} entries');
    await batch((batch) {
      batch.insertAllOnConflictUpdate(series, entries);
    });
  }

  /// Upsert series present or absent from the db and remove series not present
  /// in [entries]
  Future<void> mergeSeries(Iterable<SeriesCompanion> entries) async {
    final ids = entries.map((e) => e.id.value).toList();

    await batch((batch) {
      batch.deleteWhere(
        series,
        (s) => s.id.isNotIn(ids),
      );
      batch.insertAllOnConflictUpdate(series, entries);
    });
  }

  /// Upsert series details in [entry] and delete chapters and volumes not part
  /// of the series anymore
  Future<void> mergeSeriesDetails(SeriesDetailCompanions entry) async {
    final volumeChapters = entry.volumes
        .map((v) => v.chapters)
        .expand((cs) => cs);

    final csMap = <int, ChaptersCompanion>{};
    for (final c in entry.chapters) {
      csMap[c.id.value] = c;
    }
    for (final c in entry.storyline) {
      final existing = csMap[c.id.value];
      csMap[c.id.value] = existing != null
          ? existing.copyWith(isStoryline: c.isStoryline)
          : c;
    }
    for (final c in entry.specials) {
      final existing = csMap[c.id.value];
      csMap[c.id.value] = existing != null
          ? existing.copyWith(isSpecial: c.isSpecial)
          : c;
    }
    for (final c in volumeChapters) {
      final existing = csMap[c.id.value];
      csMap[c.id.value] = existing != null
          ? existing.copyWith(volumeId: c.volumeId)
          : c;
    }

    final chapterIds = csMap.keys;
    final volumeIds = entry.volumes.map((v) => v.volume.id.value);

    await transaction(() async {
      await batch((batch) {
        batch.deleteWhere(
          volumes,
          (t) => t.seriesId.equals(entry.seriesId) & t.id.isNotIn(volumeIds),
        );
        batch.insertAllOnConflictUpdate(
          volumes,
          entry.volumes.map((v) => v.volume),
        );
      });

      await batch((batch) {
        batch.deleteWhere(
          chapters,
          (t) => t.seriesId.equals(entry.seriesId) & t.id.isNotIn(chapterIds),
        );
        batch.insertAllOnConflictUpdate(chapters, csMap.values);
      });

      final s = await (select(
        series,
      )..where((tbl) => tbl.id.equals(entry.seriesId))).getSingle();

      final progress = entry.progress.map(
        (c) => c.copyWith(
          seriesId: Value(entry.seriesId),
          libraryId: Value(s.libraryId),
          dirty: const Value(false),
        ),
      );

      await db.readerDao.upsertCleanProgressBatch(progress);

      await managers.series
          .filter((f) => f.id(entry.seriesId))
          .update((f) => f(lastSynced: Value(DateTime.timestamp())));
    });
  }

  /// Clear all recently updated and upsert provided [entries]
  Future<void> upsertRecentlyUpdated(Iterable<SeriesCompanion> entries) async {
    await transaction(() async {
      await clearIsRecentlyUpdated();
      await upsertSeriesBatch(entries);
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

  /// Clear the want to read list
  Future<void> clearWantToRead() async {
    await delete(wantToRead).go();
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

class SeriesDetailCompanions {
  final int seriesId;
  final Iterable<ChaptersCompanion> storyline;
  final Iterable<ChaptersCompanion> specials;
  final Iterable<ChaptersCompanion> chapters;
  final Iterable<VolumeWithChaptersCompanion> volumes;
  final Iterable<ReadingProgressCompanion> progress;

  const SeriesDetailCompanions({
    required this.seriesId,
    required this.storyline,
    required this.specials,
    required this.chapters,
    required this.volumes,
    required this.progress,
  });
}
