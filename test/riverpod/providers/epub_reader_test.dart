import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';

const _series = SeriesModel(
  id: 1,
  libraryId: 1,
  name: 'Series',
  format: Format.epub,
  pages: 2,
  avgHoursToRead: 0,
  wordCount: null,
  primaryColor: null,
  secondaryColor: null,
  lastSynced: null,
);

const _chapter = ChapterModel(
  id: 2,
  seriesId: 1,
  volumeId: 1,
  title: 'Chapter',
  pages: 2,
);

const _readerState = ReaderState(
  libraryId: 1,
  series: _series,
  chapter: _chapter,
  readingListId: null,
  volumeId: 1,
  title: 'Chapter',
  totalPages: 2,
  initialPage: 0,
  bookScrollId: null,
);

class _FakeReader extends Reader {
  _FakeReader();

  final saves = <({int page, String? scrollId})>[];

  @override
  Future<ReaderState> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    return _readerState;
  }

  @override
  Future<void> saveProgress({
    required int page,
    String? scrollId,
    bool handleCompletion = true,
  }) async {
    saves.add((page: page, scrollId: scrollId));
  }

  @override
  Future<void> markComplete() async {}
}

void main() {
  test('page changes force-sync nav state and reuse cached subpage counts', () async {
    final container = _createContainer();
    final provider = _provider;
    final notifier = container.read(provider.notifier);
    await container.read(provider.future);

    expect(container.read(provider).value?.ready, isFalse);

    notifier.updateSubpageCount(0, 3);
    expect(container.read(provider).value?.ready, isTrue);
    expect(container.read(provider).value?.totalSubpages, 3);

    // Cache a count for a page that is not current without leaking it into the
    // current page's state.
    notifier.updateSubpageCount(1, 7);
    expect(container.read(provider).value?.totalSubpages, 3);

    // The cached count makes the new page ready immediately after the page
    // transition, even before its controller reports again.
    await notifier.jumpToPage(1, force: true);
    await container.pump();
    expect(container.read(provider).value?.page, 1);
    expect(container.read(provider).value?.ready, isTrue);
    expect(container.read(provider).value?.totalSubpages, 7);

    notifier.updateSubpageCount(1, 4);
    expect(container.read(provider).value?.ready, isTrue);
    expect(container.read(provider).value?.totalSubpages, 4);

    await notifier.jumpToSubpage(2, page: 1);
    await container.pump();
    expect(container.read(provider).value?.subpage, 2);

    await notifier.jumpToSubpage(1, page: 0);
    await container.pump();
    expect(container.read(provider).value?.subpage, 2);
  });

  test(
    'navigating back lands on the last subpage of the previous page',
    () async {
      final container = _createContainer();
      final notifier = container.read(_provider.notifier);
      await container.read(_provider.future);

      notifier.updateSubpageCount(0, 3);
      notifier.updateSubpageCount(1, 5);

      await notifier.jumpToPage(1, force: true);
      await container.pump();
      expect(container.read(_provider).value?.page, 1);

      await notifier.jumpToPage(0);
      await container.pump();

      expect(container.read(_provider).value?.page, 0);
      expect(container.read(_provider).value?.subpage, 2);
      expect(container.read(_provider).value?.ready, isTrue);
    },
  );

  test(
    'navigating back before the count is known waits for the last subpage',
    () async {
      final container = _createContainer();
      final notifier = container.read(_provider.notifier);
      await container.read(_provider.future);

      await notifier.jumpToPage(1, force: true);
      await container.pump();
      expect(container.read(_provider).value?.ready, isFalse);

      await notifier.jumpToPage(0, force: true);
      await container.pump();
      expect(container.read(_provider).value?.page, 0);
      expect(container.read(_provider).value?.ready, isFalse);

      notifier.updateSubpageCount(0, 4);
      await container.pump();

      expect(container.read(_provider).value?.ready, isTrue);
      expect(container.read(_provider).value?.subpage, 3);
    },
  );

  test(
    'nextPage and previousPage fall back to page jumps while measuring',
    () async {
      final container = _createContainer();
      final notifier = container.read(_provider.notifier);
      await container.read(_provider.future);

      expect(container.read(_provider).value?.ready, isFalse);

      await notifier.nextPage();
      await container.pump();
      expect(container.read(_provider).value?.page, 1);

      await notifier.previousPage();
      await container.pump();
      expect(container.read(_provider).value?.page, 0);
    },
  );

  test('carries a pending anchor to the target page', () async {
    final container = _createContainer();
    final notifier = container.read(_provider.notifier);
    await container.read(_provider.future);

    notifier.updateSubpageCount(0, 3);
    notifier.updateSubpageCount(1, 5);

    await notifier.jumpToPage(1, anchor: 'target');
    await container.pump();

    expect(container.read(_provider).value?.page, 1);
    expect(
      container.read(_provider).value?.pendingAnchor,
      (page: 1, anchor: 'target'),
    );

    // The outer PageView reports the page it settled on. That must not clear
    // the anchor that is waiting for the same page.
    await notifier.jumpToPage(1, force: true);
    await container.pump();
    expect(
      container.read(_provider).value?.pendingAnchor,
      (page: 1, anchor: 'target'),
    );

    expect(notifier.takePendingAnchor(0), isNull);
    expect(
      container.read(_provider).value?.pendingAnchor,
      (page: 1, anchor: 'target'),
    );

    expect(notifier.takePendingAnchor(1), 'target');
    expect(container.read(_provider).value?.pendingAnchor, isNull);
  });

  test('clears a pending anchor when navigating to another page', () async {
    final container = _createContainer();
    final notifier = container.read(_provider.notifier);
    await container.read(_provider.future);

    notifier.updateSubpageCount(0, 3);
    notifier.updateSubpageCount(1, 5);

    await notifier.jumpToPage(1, anchor: 'target');
    await container.pump();
    expect(
      container.read(_provider).value?.pendingAnchor,
      (page: 1, anchor: 'target'),
    );

    await notifier.jumpToPage(0);
    await container.pump();

    expect(container.read(_provider).value?.page, 0);
    expect(container.read(_provider).value?.pendingAnchor, isNull);
  });

  test('publishes a pending anchor for the current page', () async {
    final container = _createContainer();
    final notifier = container.read(_provider.notifier);
    await container.read(_provider.future);

    await notifier.jumpToPage(0, force: true, anchor: 'target');
    await container.pump();

    expect(
      container.read(_provider).value?.pendingAnchor,
      (page: 0, anchor: 'target'),
    );
    expect(notifier.takePendingAnchor(0), 'target');
    expect(container.read(_provider).value?.pendingAnchor, isNull);
  });

  test('restoring the opened position does not save progress', () async {
    final reader = _FakeReader();
    final container = _createContainer(reader: reader);
    final notifier = container.read(_provider.notifier);
    await container.read(_provider.future);

    notifier.updateSubpageCount(0, 3);
    await container.pump();

    await notifier.jumpToSubpage(
      0,
      scrollId: 'opening',
      page: 0,
      restored: true,
    );
    await container.pump();

    expect(reader.saves, isEmpty);

    await notifier.jumpToSubpage(1, scrollId: 'reading', page: 0);
    await container.pump();

    expect(reader.saves, [(page: 0, scrollId: 'reading')]);
  });

  test('restored positions still save after user navigation', () async {
    final reader = _FakeReader();
    final container = _createContainer(reader: reader);
    final notifier = container.read(_provider.notifier);
    await container.read(_provider.future);

    await notifier.jumpToPage(1, force: true);
    await container.pump();

    notifier.updateSubpageCount(1, 2);
    await container.pump();

    await notifier.jumpToSubpage(
      0,
      scrollId: 'resume',
      page: 1,
      restored: true,
    );
    await container.pump();

    expect(reader.saves.last, (page: 1, scrollId: 'resume'));
  });
}

final _provider = epubNavigationProvider(
  seriesId: 1,
  chapterId: 2,
  readingListId: null,
);

ProviderContainer _createContainer({_FakeReader? reader}) {
  final fakeReader = reader ?? _FakeReader();
  final container = ProviderContainer.test(
    overrides: [
      readerProvider(
        seriesId: 1,
        chapterId: 2,
        readingListId: null,
      ).overrideWith(() => fakeReader),
      epubReaderSettingsProvider(seriesId: 1).overrideWithBuild(
        (_, _) => const EpubReaderSettingsState(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final sub = container.listen(_provider, (_, _) {});
  addTearDown(sub.close);

  return container;
}
