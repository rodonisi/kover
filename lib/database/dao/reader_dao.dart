import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';

part 'reader_dao.g.dart';

@DriftAccessor(
  tables: [
    Series,
    Volumes,
    Chapters,
    ReadingProgress,
    ReadingListsChapters,
  ],
)
class ReaderDao extends DatabaseAccessor<AppDatabase> with _$ReaderDaoMixin {
  ReaderDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _chaptersWithProgressQuery({
    required int seriesId,
    int? volumeId,
  }) {
    final query = select(chapters).join([
      leftOuterJoin(
        readingProgress,
        readingProgress.chapterId.equalsExp(chapters.id),
      ),
      leftOuterJoin(
        volumes,
        volumes.id.equalsExp(chapters.volumeId),
      ),
    ])..where(chapters.seriesId.equals(seriesId));

    if (volumeId == null) return query;

    return query..where(chapters.volumeId.equals(volumeId));
  }

  /// Base continue point query
  JoinedSelectStatement<HasResultSet, dynamic> _continuePointQuery({
    required int seriesId,
    int? volumeId,
  }) {
    return _chaptersWithProgressQuery(seriesId: seriesId, volumeId: volumeId)
      ..orderBy([
        OrderingTerm.desc(
          readingProgress.chapterId.isNotNull() &
              readingProgress.pagesRead.isBiggerThan(const Constant(0)) &
              readingProgress.pagesRead.isSmallerThan(chapters.pages),
        ),
        OrderingTerm.desc(
          readingProgress.chapterId.isNull() |
              readingProgress.pagesRead.equals(0),
        ),
        OrderingTerm.asc(chapters.sortOrder),
        OrderingTerm.asc(volumes.minNumber),
      ])
      ..limit(1);
  }

  /// Continue point query for reading list. Orders chapters in the reading list
  /// by their progress, then by their order in the list.
  JoinedSelectStatement<HasResultSet, dynamic> _readingListContinuePointQuery({
    required int readingListId,
  }) {
    return select(chapters).join([
        innerJoin(
          readingListsChapters,
          readingListsChapters.chapterId.equalsExp(chapters.id),
        ),
        leftOuterJoin(
          readingProgress,
          readingProgress.chapterId.equalsExp(chapters.id),
        ),
      ])
      ..where(readingListsChapters.readingListId.equals(readingListId))
      ..orderBy([
        OrderingTerm.desc(
          readingProgress.chapterId.isNotNull() &
              readingProgress.pagesRead.isBiggerThan(const Constant(0)) &
              readingProgress.pagesRead.isSmallerThan(chapters.pages),
        ),
        OrderingTerm.desc(
          readingProgress.chapterId.isNull() |
              readingProgress.pagesRead.equals(0),
        ),
        OrderingTerm.asc(readingListsChapters.order),
      ])
      ..limit(1);
  }

  /// [SingleSelectable] continue point for series [seriesId]
  SingleSelectable<Chapter> continuePoint({required int seriesId}) {
    return _continuePointQuery(
      seriesId: seriesId,
    ).map((row) => row.readTable(chapters));
  }

  /// Stream of continue point for volume [volumeId]
  Stream<Chapter> watchVolumeContinuePoint({required int volumeId}) async* {
    final volume = await managers.volumes
        .filter((f) => f.id(volumeId))
        .getSingle();

    yield* _continuePointQuery(
      seriesId: volume.seriesId,
      volumeId: volumeId,
    ).map((row) => row.readTable(chapters)).watchSingle();
  }

  /// Watch continue point for reading list [readingListId]
  Stream<Chapter> watchReadingListContinuePoint({required int readingListId}) {
    final query = _readingListContinuePointQuery(readingListId: readingListId);
    return query.map((row) => row.readTable(chapters)).watchSingle();
  }

  /// Watch progress percent for continue point of reading list [readingListId]
  Stream<double> watchReadingListContinuePointProgress({
    required int readingListId,
  }) {
    final query = _readingListContinuePointQuery(readingListId: readingListId);
    return query.watchSingleOrNull().map((row) {
      if (row == null) return 0.0;
      final chapter = row.readTable(chapters);
      final progress = row.readTableOrNull(readingProgress);
      if (progress == null || chapter.pages == 0) return 0.0;
      return progress.pagesRead / chapter.pages;
    });
  }

  /// Watch progress percent for continue point of series [seriesId]
  Stream<double> watchContinuePointProgress({required int seriesId}) {
    return _continuePointQuery(seriesId: seriesId).watchSingleOrNull().map((
      row,
    ) {
      if (row == null) return 0.0;
      final chapter = row.readTable(chapters);
      final progress = row.readTableOrNull(readingProgress);
      if (progress == null || chapter.pages == 0) return 0.0;
      return progress.pagesRead / chapter.pages;
    });
  }

  /// Get progress for chapter [chapterId]
  Future<ReadingProgressData?> getProgress(int chapterId) {
    return (select(
      readingProgress,
    )..where((row) => row.chapterId.equals(chapterId))).getSingleOrNull();
  }

  /// Get all dirty progress entries
  Future<List<ReadingProgressData>> getDirtyProgress() async {
    return await managers.readingProgress.filter((f) => f.dirty(true)).get();
  }

  /// Get all chapter ids with outdated progress
  Future<List<int>> getOutdatedChapterIds() async {
    return managers.readingProgress
        .filter(
          (f) => f.lastModified.column.isSmallerThan(
            f.chapterId.remoteLastRead.column,
          ),
        )
        .map((e) => e.chapterId)
        .get();
  }

  /// Get last read date per series for all series that have progress entries
  Future<Map<int, DateTime>> getLastReadDatePerSeries() async {
    final result =
        await (selectOnly(readingProgress)
              ..addColumns([
                readingProgress.seriesId,
                readingProgress.lastModified.max(),
              ])
              ..groupBy([readingProgress.seriesId]))
            .get();

    return {
      for (final row in result)
        row.read(readingProgress.seriesId)!: row.read(
          readingProgress.lastModified.max(),
        )!,
    };
  }

  /// Upsert progress entry. Returns the inserted or updated entry
  Future<ReadingProgressData> upsertProgress(
    ReadingProgressCompanion entry,
  ) async {
    return await into(
      readingProgress,
    ).insertReturning(
      entry,
      onConflict: DoUpdate((old) => entry),
    );
  }

  /// Merge a progress batch. Updates all entries that are last modified at the
  /// same time or before the existing dirty progress entry
  Future<List<ReadingProgressData>> mergeProgressBatch(
    Iterable<ReadingProgressCompanion> incomingList,
  ) async {
    final ids = incomingList.map((p) => p.chapterId.value).toList();
    final localRecords = await managers.readingProgress
        .filter((f) => f.chapterId.id.isIn(ids))
        .get();
    final localMap = {for (var r in localRecords) r.chapterId: r};

    final toUpdate = incomingList.where((incoming) {
      final local = localMap[incoming.chapterId.value];

      return !_localWins(
        local: local,
        incoming: incoming,
      );
    }).toList();

    if (toUpdate.isNotEmpty) {
      await batch((b) {
        b.insertAllOnConflictUpdate(readingProgress, toUpdate);
      });
    }

    return await managers.readingProgress
        .filter((f) => f.dirty.equals(true))
        .get();
  }

  /// Clear dirty flag for all progress entries for the given [chapterIds]
  Future<void> clearDirtyFlags(Iterable<int> chapterIds) async {
    await managers.readingProgress
        .filter((f) => f.chapterId.id.isIn(chapterIds))
        .update((u) => u(dirty: const Value(false)));
  }

  /// Watch previous chapter for chapter [chapterId]
  Stream<Chapter?> watchPrevChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
    int? readingListId,
  }) {
    if (readingListId == null) {
      final sortOrderOfCurrent = subqueryExpression<double>(
        selectOnly(chapters)
          ..addColumns([chapters.sortOrder])
          ..where(chapters.id.equals(chapterId)),
      );

      final query = select(chapters)
        ..where((c) {
          final base =
              c.seriesId.equals(seriesId) &
              c.sortOrder.isSmallerThan(sortOrderOfCurrent);
          return volumeId != null ? base & c.volumeId.equals(volumeId) : base;
        })
        ..orderBy([(c) => OrderingTerm.desc(c.sortOrder)])
        ..limit(1);

      return query.watchSingleOrNull();
    }

    final orderOfCurrentInList = subqueryExpression<int>(
      selectOnly(readingListsChapters)
        ..addColumns([
          readingListsChapters.order,
        ])
        ..where(
          readingListsChapters.readingListId.equals(readingListId) &
              readingListsChapters.chapterId.equals(chapterId),
        ),
    );

    final joinedQuery = select(chapters).join([
      innerJoin(
        readingListsChapters,
        readingListsChapters.chapterId.equalsExp(chapters.id),
      ),
    ]);

    joinedQuery.where(
      readingListsChapters.readingListId.equals(readingListId) &
          readingListsChapters.order.isSmallerThan(orderOfCurrentInList),
    );

    joinedQuery.orderBy([OrderingTerm.desc(readingListsChapters.order)]);
    joinedQuery.limit(1);

    return joinedQuery
        .map((row) => row.readTable(chapters))
        .watchSingleOrNull();
  }

  /// Watch next chapter for chapter [chapterId]
  Stream<Chapter?> watchNextChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
    int? readingListId,
  }) {
    if (readingListId == null) {
      final sortOrderOfCurrent = subqueryExpression<double>(
        selectOnly(chapters)
          ..addColumns([chapters.sortOrder])
          ..where(chapters.id.equals(chapterId)),
      );

      final query = select(chapters)
        ..where((c) {
          final base =
              c.seriesId.equals(seriesId) &
              c.sortOrder.isBiggerThan(sortOrderOfCurrent);
          return volumeId != null ? base & c.volumeId.equals(volumeId) : base;
        })
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])
        ..limit(1);

      return query.watchSingleOrNull();
    }

    final orderOfCurrentInList = subqueryExpression<int>(
      selectOnly(readingListsChapters)
        ..addColumns([readingListsChapters.order])
        ..where(
          readingListsChapters.readingListId.equals(readingListId) &
              readingListsChapters.chapterId.equals(chapterId),
        ),
    );

    final joinedQuery = select(chapters).join([
      innerJoin(
        readingListsChapters,
        readingListsChapters.chapterId.equalsExp(chapters.id),
      ),
    ]);

    joinedQuery.where(
      readingListsChapters.readingListId.equals(readingListId) &
          readingListsChapters.order.isBiggerThan(orderOfCurrentInList),
    );

    joinedQuery.orderBy([OrderingTerm.asc(readingListsChapters.order)]);
    joinedQuery.limit(1);

    return joinedQuery
        .map((row) => row.readTable(chapters))
        .watchSingleOrNull();
  }

  /// Mark all chapters for [seriesId] as [isRead]
  Future<void> markSeriesRead(int seriesId, {required bool isRead}) async {
    await transaction(() async {
      final query =
          (select(
            chapters,
          )..where((row) => row.seriesId.equals(seriesId))).join([
            innerJoin(series, series.id.equalsExp(chapters.seriesId)),
          ]);

      final progressBatch = (await query.get()).map((join) {
        final c = join.readTable(chapters);
        final s = join.readTable(series);

        return ReadingProgressCompanion(
          chapterId: Value(c.id),
          volumeId: Value(c.volumeId),
          seriesId: Value(s.id),
          libraryId: Value(s.libraryId),
          pagesRead: Value(isRead ? c.pages : 0),
          lastModified: Value(DateTime.timestamp()),
          dirty: const Value(true),
        );
      });

      await batch((batch) {
        batch.insertAllOnConflictUpdate(readingProgress, progressBatch);
      });
    });
  }

  /// Mark all chapters for [volumeId] as [isRead]
  Future<void> markVolumeRead(
    int volumeId, {
    required bool isRead,
  }) async {
    await transaction(() async {
      final query =
          (select(
                chapters,
              )..where(
                (row) => row.volumeId.equals(volumeId),
              ))
              .join([
                innerJoin(series, series.id.equalsExp(chapters.seriesId)),
              ]);

      final progressBatch = (await query.get()).map((join) {
        final c = join.readTable(chapters);
        final s = join.readTable(series);

        return ReadingProgressCompanion(
          chapterId: Value(c.id),
          volumeId: Value(c.volumeId),
          seriesId: Value(s.id),
          libraryId: Value(s.libraryId),
          pagesRead: Value(isRead ? c.pages : 0),
          lastModified: Value(DateTime.timestamp()),
          dirty: const Value(true),
        );
      });

      await batch((batch) {
        batch.insertAllOnConflictUpdate(readingProgress, progressBatch);
      });
    });
  }

  /// Mark chapter [chapterId] as [isRead]
  Future<void> markChapterRead(int chapterId, {required bool isRead}) async {
    await transaction(() async {
      final join =
          await (select(
            chapters,
          )..where((tbl) => tbl.id.equals(chapterId))).join([
            innerJoin(series, series.id.equalsExp(chapters.seriesId)),
          ]).getSingle();

      final c = join.readTable(chapters);
      final s = join.readTable(series);

      await into(
        readingProgress,
      ).insertOnConflictUpdate(
        ReadingProgressCompanion(
          chapterId: Value(c.id),
          volumeId: Value(c.volumeId),
          seriesId: Value(s.id),
          libraryId: Value(s.libraryId),
          pagesRead: Value(isRead ? c.pages : 0),
          lastModified: Value(DateTime.timestamp()),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// Progress data merge local wins condition
  static bool _localWins({
    ReadingProgressData? local,
    required ReadingProgressCompanion incoming,
  }) {
    return local != null &&
        local.dirty &&
        local.lastModified.isAfter(incoming.lastModified.value);
  }
}
