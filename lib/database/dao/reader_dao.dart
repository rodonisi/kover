import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/utils/logging.dart';

part 'reader_dao.g.dart';

@DriftAccessor(tables: [Series, Chapters, ReadingProgress])
class ReaderDao extends DatabaseAccessor<AppDatabase> with _$ReaderDaoMixin {
  ReaderDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _chaptersWithProgressQuery({
    required int seriesId,
  }) {
    return select(chapters).join([
      leftOuterJoin(
        readingProgress,
        readingProgress.chapterId.equalsExp(chapters.id),
      ),
    ])..where(chapters.seriesId.equals(seriesId));
  }

  /// Base continue point query
  JoinedSelectStatement<HasResultSet, dynamic> _continuePointQuery({
    required int seriesId,
  }) {
    return _chaptersWithProgressQuery(seriesId: seriesId)
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
      ])
      ..limit(1);
  }

  /// [SingleSelectable] continue point for series [seriesId]
  SingleSelectable<Chapter> continuePoint({required int seriesId}) {
    return _continuePointQuery(
      seriesId: seriesId,
    ).map((row) => row.readTable(chapters));
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

  /// Get last read date for all chapters of series [seriesId]
  Future<Map<int, DateTime?>> getLastReadDatePerSeriesChapters({
    required int seriesId,
  }) async {
    final result = await _chaptersWithProgressQuery(seriesId: seriesId).get();

    return {
      for (final entry in result)
        entry.readTable(chapters).id: entry
            .readTableOrNull(readingProgress)
            ?.lastModified,
    };
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
    log.d('upsert progress chapter=${entry.chapterId.value}');
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

  /// Upsert chapter progress batch only where the existing progress is not
  /// dirty
  Future<void> upsertCleanProgressBatch(
    Iterable<ReadingProgressCompanion> incoming,
  ) async {
    await transaction(() async {
      if (incoming.isEmpty) return;

      final ids = incoming.map((e) => e.chapterId.value).toList();

      final existing = {
        for (final row in await (select(
          readingProgress,
        )..where((r) => r.chapterId.isIn(ids))).get())
          row.chapterId: row,
      };

      final toWrite = <ReadingProgressCompanion>[];
      for (final entry in incoming) {
        final local = existing[entry.chapterId.value];

        final localWins = local != null && local.dirty;

        if (!localWins) {
          toWrite.add(entry);
        }
      }

      log.d('upserting progress batch with ${toWrite.length} entries');
      await batch((b) => b.insertAllOnConflictUpdate(readingProgress, toWrite));
    });
  }

  /// Watch previous chapter for chapter [chapterId]
  Stream<Chapter?> watchPrevChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
  }) {
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

  /// Watch next chapter for chapter [chapterId]
  Stream<Chapter?> watchNextChapter({
    required int seriesId,
    int? volumeId,
    required int chapterId,
  }) {
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
