import 'package:flutter/foundation.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reader/image_spreads_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
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

/// The pages that should be bookmarked for the currently visible view. In
/// spread mode this is every page of the current spread, otherwise it is the
/// single current page.
@riverpod
Future<List<int>> currentBookmarkPages(
  Ref ref, {
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

  final mode = await ref.watch(
    imageReaderSettingsProvider(
      seriesId: seriesId,
    ).selectAsync((settings) => settings.readerMode),
  );

  if (mode != ReaderMode.spread) return [nav.currentPage];

  final spreads = await ref.watch(
    spreadsProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );

  final spreadIndex = spreads.spreads.indexWhere(
    (spread) => spread.contains(nav.currentPage),
  );

  if (spreadIndex == -1) return [nav.currentPage];

  return spreads.spreads[spreadIndex];
}

@riverpod
class CurrentPageBookmark extends _$CurrentPageBookmark {
  @override
  Future<bool> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    final pages = await ref.watch(
      currentBookmarkPagesProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );

    final bookmarked = await Future.wait(
      pages.map(
        (page) => ref.watch(
          pageBookmarkedProvider(
            chapterId: chapterId,
            page: page,
          ).future,
        ),
      ),
    );

    return bookmarked.every((bookmarked) => bookmarked);
  }

  Future<void> toggle() async {
    final pages = await ref.read(
      currentBookmarkPagesProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );
    final repo = ref.read(bookmarkRepositoryProvider);
    if (await future) {
      for (final page in pages) {
        await repo.removeBookmark(chapterId: chapterId, page: page);
      }
    } else {
      final chapter = await ref
          .read(chaptersRepositoryProvider)
          .getChapter(chapterId: chapterId);
      for (final page in pages) {
        await repo.addBookmark(
          seriesId: chapter.seriesId,
          volumeId: chapter.volumeId,
          chapterId: chapterId,
          page: page,
        );
      }
    }
  }
}

@riverpod
Future<ImageModel> bookmarkImage(Ref ref, BookmarkModel bookmark) {
  final page = imagePageProvider(
    chapterId: bookmark.chapterId,
    page: bookmark.page,
  );

  ref.listen(hasConnectionProvider, (previous, next) {
    if (next.value ?? false) ref.invalidate(page);
  });

  return ref.watch(page.future);
}

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
