import 'package:flutter/foundation.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/reader.dart';
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

@riverpod
Future<ImageModel> bookmarkImage(Ref ref, BookmarkModel bookmark) {
  final page = imagePageProvider(
    chapterId: bookmark.chapterId,
    page: bookmark.page,
  );

  // A failed page fetch is cached until the provider is disposed. Drop it when
  // connectivity is regained so previews recover.
  ref.listen(hasConnectionProvider, (previous, next) {
    if (next.value ?? false) ref.invalidate(page);
  });

  return ref.watch(page.future);
}

/// Every non-removed image bookmark in the given scope, ordered by chapter
/// sort order then page.
@riverpod
Stream<List<BookmarkModel>> bookmarks(
  Ref ref, {
  int? seriesId,
  int? volumeId,
  int? chapterId,
}) {
  final repo = ref.watch(bookmarkRepositoryProvider);
  return repo
      .watchBookmarks(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      )
      .distinct(listEquals);
}

/// The subset of [bookmarks] whose chapter can currently be read, i.e. it is
/// downloaded or there is connectivity. Non-fetchable bookmarks are excluded.
@riverpod
List<BookmarkModel> readableBookmarks(
  Ref ref, {
  int? seriesId,
  int? volumeId,
  int? chapterId,
}) {
  final bookmarks =
      ref
          .watch(
            bookmarksProvider(
              seriesId: seriesId,
              volumeId: volumeId,
              chapterId: chapterId,
            ),
          )
          .value ??
      const [];

  return bookmarks
      .where(
        (bookmark) =>
            ref.watch(canReadChapterProvider(bookmark.chapterId)).value ??
            false,
      )
      .toList();
}
