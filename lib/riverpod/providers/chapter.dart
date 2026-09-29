import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'chapter.g.dart';

@riverpod
Stream<List<ChapterModel>> filteredChapters(
  Ref ref, {
  required int seriesId,
  int? volumeId,
  ChapterKind kind = .chapters,
  String query = '',
  OrderedSortOption orderBy = .sortOrder,
  SortDirection direction = .ascending,
  bool hideRead = false,
  bool downloadedOnly = false,
}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo
      .watchFilteredChapters(
        seriesId: seriesId,
        volumeId: volumeId,
        kind: kind,
        query: query,
        orderBy: orderBy,
        direction: direction,
        hideRead: hideRead,
        downloadedOnly: downloadedOnly,
      )
      .distinct();
}

@riverpod
Stream<ChapterModel> chapter(
  Ref ref, {
  required int chapterId,
}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo.watchChapter(chapterId: chapterId).distinct();
}

@riverpod
Stream<ChapterModel> chapterMetadata(
  Ref ref, {
  required int chapterId,
}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo.watchChapterWithMetadata(chapterId: chapterId).distinct();
}

@riverpod
Future<List<ChapterModel>> searchChapters(
  Ref ref,
  String query, {
  int? volumeId,
  int? seriesId,
}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo.searchChapters(
    query,
    volumeId: volumeId,
    seriesId: seriesId,
  );
}

@riverpod
Stream<double> chapterProgress(Ref ref, {required int chapterId}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  final chapter = repo.watchChapter(chapterId: chapterId);
  final pagesRead = repo.watchPagesRead(chapterId: chapterId);

  return Rx.combineLatest2(
    chapter,
    pagesRead,
    (c, n) => n / c.pages,
  ).distinct();
}

@riverpod
Stream<ImageModel?> chapterCover(Ref ref, {required int chapterId}) {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo.watchChapterCover(chapterId).distinct();
}
