import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/download.dart';
import 'package:rxdart/rxdart.dart';

part 'download_dao.g.dart';

@DriftAccessor(tables: [DownloadedPages, Chapters])
class DownloadDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadDaoMixin {
  DownloadDao(super.attachedDatabase);

  /// Returns whether ALL pages of a chapter [chapterId] are stored locally.
  SingleSelectable<bool> isChapterDownloaded({required int chapterId}) {
    final downloadedCount = downloadedPages.chapterId.count();

    final query = selectOnly(chapters)
      ..addColumns([chapters.pages, downloadedCount])
      ..where(chapters.id.equals(chapterId));

    query.join([
      leftOuterJoin(
        downloadedPages,
        downloadedPages.chapterId.equalsExp(chapters.id),
        useColumns: false,
      ),
    ]);

    return query.map((row) {
      final total = row.read(chapters.pages) ?? 0;
      final downloaded = row.read(downloadedCount) ?? 0;
      return total > 0 && downloaded >= total;
    });
  }

  /// Returns the number of pages currently stored for chapter [chapterId].
  Future<int> downloadedPageCount({required int chapterId}) {
    return managers.downloadedPages
        .filter((f) => f.chapterId.id(chapterId))
        .count();
  }

  /// Returns download progress percentage for chapter [chapterId].
  SingleSelectable<double> dowloadPercent({required int chapterId}) {
    final countColumn = downloadedPages.chapterId.count();

    final query =
        selectOnly(downloadedPages).join([
            innerJoin(
              chapters,
              chapters.id.equalsExp(downloadedPages.chapterId),
            ),
          ])
          ..addColumns([countColumn, chapters.pages])
          ..where(downloadedPages.chapterId.equals(chapterId));

    return query.map((row) {
      final downloaded = row.read(countColumn) ?? 0;
      final total = row.read(chapters.pages) ?? 0;
      return total > 0 ? downloaded / total : 0.0;
    });
  }

  /// Fetches a specific page blob by chapterId + page index.
  SingleSelectable<DownloadedPage> getPage({
    required int chapterId,
    required int page,
  }) {
    return managers.downloadedPages.filter(
      (f) => f.chapterId.id(chapterId) & f.page(page),
    );
  }

  /// Persists a single page blob. Replaces any existing entry for the same
  /// (chapterId, page) composite key.
  Future<void> insertPage(DownloadedPagesCompanion entry) {
    return into(downloadedPages).insertOnConflictUpdate(entry);
  }

  /// Deletes all downloaded pages for a chapter.
  Future<void> deleteChapter({required int chapterId}) async {
    await transaction(() async {
      await managers.downloadedPages
          .filter((f) => f.chapterId.id(chapterId))
          .delete();
    });
  }

  Future<void> deleteVolume({required int volumeId}) async {
    await transaction(() async {
      final chapterIdsQuery = selectOnly(chapters)
        ..addColumns([chapters.id])
        ..where(chapters.volumeId.equals(volumeId));

      await (delete(
        downloadedPages,
      )..where((tbl) => tbl.chapterId.isInQuery(chapterIdsQuery))).go();
    });
  }

  Future<void> deleteSeries({required int seriesId}) async {
    await transaction(() async {
      final chapterIdsQuery = selectOnly(chapters)
        ..addColumns([chapters.id])
        ..where(chapters.seriesId.equals(seriesId));

      await (delete(
        downloadedPages,
      )..where((tbl) => tbl.chapterId.isInQuery(chapterIdsQuery))).go();
    });
  }

  /// Reactively emits the percentage of downloaded pages for [volumeId]
  Stream<double> watchDownloadedProgressByVolume({required int volumeId}) {
    final totalPagesQuery = selectOnly(chapters)
      ..addColumns([chapters.pages.sum()])
      ..where(chapters.volumeId.equals(volumeId));

    final downloadedCountQuery = selectOnly(downloadedPages)
      ..addColumns([downloadedPages.chapterId.count()])
      ..join([
        innerJoin(chapters, chapters.id.equalsExp(downloadedPages.chapterId)),
      ])
      ..where(chapters.volumeId.equals(volumeId));

    return Rx.combineLatest2<int?, int?, double>(
      totalPagesQuery.watchSingle().map(
        (row) => row.read(chapters.pages.sum()),
      ),
      downloadedCountQuery.watchSingle().map(
        (row) => row.read(downloadedPages.chapterId.count()),
      ),
      (total, downloaded) {
        final totalVal = total ?? 0;
        final downloadedVal = downloaded ?? 0;
        if (totalVal == 0) return 0.0;
        return (downloadedVal / totalVal).clamp(0.0, 1.0);
      },
    );
  }

  /// Reactively emits the percentage of downloaded pages for [seriesId]
  Stream<double> watchDownloadedProgressBySeries({required int seriesId}) {
    final totalPagesQuery = selectOnly(chapters)
      ..addColumns([chapters.pages.sum()])
      ..where(chapters.seriesId.equals(seriesId));

    final downloadedCountQuery = selectOnly(downloadedPages)
      ..addColumns([downloadedPages.chapterId.count()])
      ..join([
        innerJoin(chapters, chapters.id.equalsExp(downloadedPages.chapterId)),
      ])
      ..where(chapters.seriesId.equals(seriesId));

    return Rx.combineLatest2<int?, int?, double>(
      totalPagesQuery.watchSingle().map(
        (row) => row.read(chapters.pages.sum()),
      ),
      downloadedCountQuery.watchSingle().map(
        (row) => row.read(downloadedPages.chapterId.count()),
      ),
      (total, downloaded) {
        final totalVal = total ?? 0;
        final downloadedVal = downloaded ?? 0;
        if (totalVal == 0) return 0.0;
        return (downloadedVal / totalVal).clamp(0.0, 1.0);
      },
    );
  }
}
