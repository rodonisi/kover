import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reader/image_spreads_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/bookmark_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<BookRepository>(),
  MockSpec<BookmarkRepository>(),
  MockSpec<ChaptersRepository>(),
])
import 'bookmark_test.mocks.dart';

class _FakeReaderNavigation extends ReaderNavigation {
  _FakeReaderNavigation(this._page);

  final int _page;

  @override
  Future<ReaderNavigationState> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    return ReaderNavigationState(
      currentPage: _page,
      totalPages: 10,
      fromObserver: false,
      handleCompletion: true,
    );
  }
}

class _FakeImageReaderSettings extends ImageReaderSettings {
  _FakeImageReaderSettings(this._mode);

  final ReaderMode _mode;

  @override
  Future<ImageReaderSettingsState> build({required int seriesId}) async {
    return ImageReaderSettingsState(readerMode: _mode);
  }
}

class _FakeSpreads extends Spreads {
  _FakeSpreads(this._state);

  final SpreadsState _state;

  @override
  Future<SpreadsState> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async => _state;
}

void main() {
  provideDummy<ImageModel>(ImageModel(data: Uint8List(0)));
  provideDummy<ChapterModel>(
    const ChapterModel(
      id: 1,
      seriesId: 1,
      volumeId: 1,
      title: 'Chapter',
      pages: 1,
    ),
  );

  BookmarkModel bookmark({required int id, required int chapterId}) {
    return BookmarkModel(
      id: id,
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      page: id,
      imageOffset: 0,
      created: DateTime(2026),
    );
  }

  test('readableBookmarks keeps only chapters that can be read', () async {
    final readable = bookmark(id: 1, chapterId: 1);
    final notReadable = bookmark(id: 2, chapterId: 2);

    final container = ProviderContainer.test(
      overrides: [
        bookmarksProvider(
          seriesId: 1,
        ).overrideWith((ref) => Stream.value([readable, notReadable])),
        canReadChapterProvider(1).overrideWith((ref) => Stream.value(true)),
        canReadChapterProvider(2).overrideWith((ref) => Stream.value(false)),
      ],
    );

    final subscription = container.listen(
      readableBookmarksProvider(seriesId: 1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(bookmarksProvider(seriesId: 1).future);
    await container.read(canReadChapterProvider(1).future);
    await container.read(canReadChapterProvider(2).future);
    await container.pump();

    expect(subscription.read(), [readable]);
  });

  test('bookmarkImage refetches when connectivity is regained', () async {
    final target = bookmark(id: 1, chapterId: 10);
    final repo = MockBookRepository();
    var attempts = 0;
    when(repo.getImagePage(chapterId: 10, page: 1)).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      return ImageModel(data: Uint8List.fromList([1, 2, 3]));
    });

    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookRepositoryProvider.overrideWithValue(repo),
        hasConnectionProvider.overrideWith((ref) => connectivity.stream),
      ],
    );

    final subscription = container.listen(
      bookmarkImageProvider(target),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(bookmarkImageProvider(target).future),
      throwsA(isA<Exception>()),
    );
    expect(attempts, 1);

    connectivity.add(true);
    await container.pump();

    final image = await container.read(bookmarkImageProvider(target).future);
    expect(image.data, [1, 2, 3]);
    expect(attempts, 2);
  });

  group('currentBookmarkPages', () {
    ProviderContainer containerWith({
      required int currentPage,
      required ReaderMode mode,
      required List<List<int>> spreads,
    }) {
      return ProviderContainer.test(
        overrides: [
          readerNavigationProvider(
            seriesId: 1,
            chapterId: 1,
            readingListId: null,
          ).overrideWith(() => _FakeReaderNavigation(currentPage)),
          imageReaderSettingsProvider(
            seriesId: 1,
          ).overrideWith(() => _FakeImageReaderSettings(mode)),
          spreadsProvider(
            seriesId: 1,
            chapterId: 1,
            readingListId: null,
          ).overrideWith(
            () => _FakeSpreads(
              SpreadsState(spreads: spreads, checkedPages: const {}),
            ),
          ),
        ],
      );
    }

    test('returns every page of the current spread in spread mode', () async {
      final container = containerWith(
        currentPage: 5,
        mode: ReaderMode.spread,
        spreads: const [
          [0],
          [1, 2],
          [3, 4],
          [5, 6],
        ],
      );

      final pages = await container.read(
        currentBookmarkPagesProvider(
          seriesId: 1,
          chapterId: 1,
          readingListId: null,
        ).future,
      );

      expect(pages, [5, 6]);
    });

    test('returns a single page for a lone cover spread', () async {
      final container = containerWith(
        currentPage: 0,
        mode: ReaderMode.spread,
        spreads: const [
          [0],
          [1, 2],
        ],
      );

      final pages = await container.read(
        currentBookmarkPagesProvider(
          seriesId: 1,
          chapterId: 1,
          readingListId: null,
        ).future,
      );

      expect(pages, [0]);
    });

    test('returns the current page outside spread mode', () async {
      final container = containerWith(
        currentPage: 5,
        mode: ReaderMode.horizontal,
        spreads: const [
          [5, 6],
        ],
      );

      final pages = await container.read(
        currentBookmarkPagesProvider(
          seriesId: 1,
          chapterId: 1,
          readingListId: null,
        ).future,
      );

      expect(pages, [5]);
    });
  });

  group('CurrentPageBookmark', () {
    const seriesId = 1;
    const chapterId = 1;

    ProviderContainer containerWith({
      required List<int> pages,
      required Set<int> bookmarked,
      BookmarkRepository? repo,
      ChaptersRepository? chapters,
    }) {
      return ProviderContainer.test(
        overrides: [
          currentBookmarkPagesProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            readingListId: null,
          ).overrideWith((ref) => pages),
          for (final page in pages)
            pageBookmarkedProvider(
              chapterId: chapterId,
              page: page,
            ).overrideWith((ref) => Stream.value(bookmarked.contains(page))),
          if (repo != null) bookmarkRepositoryProvider.overrideWithValue(repo),
          if (chapters != null)
            chaptersRepositoryProvider.overrideWithValue(chapters),
        ],
      );
    }

    Future<bool> readBookmarked(ProviderContainer container) {
      return container.read(
        currentPageBookmarkProvider(
          seriesId: seriesId,
          chapterId: chapterId,
          readingListId: null,
        ).future,
      );
    }

    Future<void> toggle(ProviderContainer container) {
      return container
          .read(
            currentPageBookmarkProvider(
              seriesId: seriesId,
              chapterId: chapterId,
              readingListId: null,
            ).notifier,
          )
          .toggle();
    }

    test(
      'is not bookmarked while any page in the spread is unbookmarked',
      () async {
        final container = containerWith(pages: [5, 6], bookmarked: {5});

        expect(await readBookmarked(container), isFalse);
      },
    );

    test('is bookmarked when every page in the spread is bookmarked', () async {
      final container = containerWith(pages: [5, 6], bookmarked: {5, 6});

      expect(await readBookmarked(container), isTrue);
    });

    test('toggle adds every page of the spread', () async {
      final repo = MockBookmarkRepository();
      final chapters = MockChaptersRepository();
      when(chapters.getChapter(chapterId: chapterId)).thenAnswer(
        (_) async => const ChapterModel(
          id: chapterId,
          seriesId: seriesId,
          volumeId: 7,
          title: 'Chapter',
          pages: 10,
        ),
      );

      final container = containerWith(
        pages: [5, 6],
        bookmarked: {},
        repo: repo,
        chapters: chapters,
      );

      await toggle(container);

      verify(
        repo.addBookmark(
          seriesId: seriesId,
          volumeId: 7,
          chapterId: chapterId,
          page: 5,
        ),
      ).called(1);
      verify(
        repo.addBookmark(
          seriesId: seriesId,
          volumeId: 7,
          chapterId: chapterId,
          page: 6,
        ),
      ).called(1);
      verifyNever(
        repo.removeBookmark(
          chapterId: anyNamed('chapterId'),
          page: anyNamed('page'),
        ),
      );
    });

    test('toggle removes every page of the spread', () async {
      final repo = MockBookmarkRepository();

      final container = containerWith(
        pages: [5, 6],
        bookmarked: {5, 6},
        repo: repo,
      );

      await toggle(container);

      verify(repo.removeBookmark(chapterId: chapterId, page: 5)).called(1);
      verify(repo.removeBookmark(chapterId: chapterId, page: 6)).called(1);
      verifyNever(
        repo.addBookmark(
          seriesId: anyNamed('seriesId'),
          volumeId: anyNamed('volumeId'),
          chapterId: anyNamed('chapterId'),
          page: anyNamed('page'),
        ),
      );
    });
  });
}
