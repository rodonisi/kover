import 'package:kover/models/bookmark_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/repository/bookmark_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bookmark.g.dart';

@riverpod
Stream<bool> pageBookmarked(
  Ref ref, {
  required int chapterId,
  required int page,
  int pageOffset = 0,
  String? xPath,
}) {
  return ref
      .watch(bookmarkRepositoryProvider)
      .watchPageBookmark(
        chapterId: chapterId,
        page: page,
        pageOffset: pageOffset,
        xPath: xPath,
      );
}

@riverpod
class CurrentPageBookmark extends _$CurrentPageBookmark {
  @override
  Future<bool> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    final nav = await ref.watch(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );
    return ref.watch(
      pageBookmarkedProvider(
        chapterId: chapterId,
        page: nav.currentPage,
      ).future,
    );
  }

  Future<void> toggle() async {
    final nav = await ref.read(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );
    final repo = ref.read(bookmarkRepositoryProvider);
    if (await future) {
      await repo.removeBookmark(chapterId: chapterId, page: nav.currentPage);
    } else {
      final chapter = await ref
          .read(chaptersRepositoryProvider)
          .getChapter(chapterId: chapterId);
      await repo.addBookmark(
        seriesId: chapter.seriesId,
        volumeId: chapter.volumeId,
        chapterId: chapterId,
        page: nav.currentPage,
      );
    }
  }
}
// Future<void> bookmark() async {
//   final repo = ref.read(bookmarkRepositoryProvider);
//   final chapter = await ref.read(
//     chapterProvider(chapterId: chapterId).future,
//   );
//   await repo.addBookmark(
//     seriesId: chapter.seriesId,
//     volumeId: chapter.volumeId,
//     chapterId: chapterId,
//     page: page,
//   );
// }
//
// Future<void> removeBookmark() async {
//   final repo = ref.read(bookmarkRepositoryProvider);
//   await repo.removeBookmark(chapterId: chapterId, page: page);
// }
// }

@riverpod
Future<ImageModel> bookmarkImage(Ref ref, BookmarkModel bookmark) async {
  return ref.watch(
    imagePageProvider(
      chapterId: bookmark.chapterId,
      page: bookmark.page,
    ).future,
  );
}

// @riverpod
// Stream<List<BookmarkModel>> chapterBookmarks(
//   Ref ref, {
//   required int chapterId,
// }) {
//   final repo = ref.watch(bookmarkRepositoryProvider);
//   return repo.watchChapterBookmarks(chapterId);
// }
//
// @riverpod
// Stream<List<int>> chapterIdsWithBookmarks(
//   Ref ref, {
//   int? seriesId,
//   int? volumeId,
// }) {
//   final repo = ref.watch(bookmarkRepositoryProvider);
//   return repo.watchChapterIdsWithBookmarks(
//     seriesId: seriesId,
//     volumeId: volumeId,
//   );
// }
//
// @riverpod
// Stream<List<SeriesModel>> bookmarkedSeries(Ref ref) {
//   final repo = ref.watch(bookmarkRepositoryProvider);
//   return repo.watchBookmarkedSeries();
// }
//
// @riverpod
// Stream<List<ChapterModel>> bookmarkedChapters(
//   Ref ref, {
//   int? seriesId,
//   int? volumeId,
// }) {
//   final repo = ref.watch(bookmarkRepositoryProvider);
//   return repo.watchBookmarkedChapters(
//     seriesId: seriesId,
//     volumeId: volumeId,
//   );
// }
