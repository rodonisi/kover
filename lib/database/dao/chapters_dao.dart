import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/progress.dart';

part 'chapters_dao.g.dart';

@DriftAccessor(tables: [Chapters, ChapterCovers, ReadingProgress])
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
    final q = managers.chapters.filter(
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
}
