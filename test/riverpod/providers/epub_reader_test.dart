import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'epub_reader_test.mocks.dart';

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

final _provider = epubNavigationProvider(
  seriesId: 1,
  chapterId: 2,
  readingListId: null,
);

@GenerateNiceMocks([MockSpec<Reader>()])
void main() {
  late MockReader reader;
  late ProviderContainer container;
  late EpubNavigation notifier;

  setUp(() async {
    reader = MockReader();
    container = _createContainer(_ReaderAdapter(reader));
    notifier = container.read(_provider.notifier);
    await container.read(_provider.future);
  });

  group('EpubNavigation', () {
    group('subpage counts', () {
      test('starts unready', () {
        expect(_state(container).ready, isFalse);
      });

      test('current-page count publishes readiness and total', () {
        notifier.updateSubpageCount(0, 3);

        expect(_state(container).ready, isTrue);
        expect(_state(container).totalSubpages, 3);
      });

      test('other-page count does not change current state', () {
        notifier.updateSubpageCount(0, 3);

        notifier.updateSubpageCount(1, 7);

        expect(_state(container).totalSubpages, 3);
      });

      test('page jump adopts the cached count', () async {
        notifier.updateSubpageCount(0, 3);
        notifier.updateSubpageCount(1, 7);

        await notifier.jumpToPage(1, force: true);
        await container.pump();

        expect(_state(container).page, 1);
        expect(_state(container).ready, isTrue);
        expect(_state(container).totalSubpages, 7);
      });

      test('current-page report replaces the cached count', () async {
        notifier.updateSubpageCount(0, 3);
        notifier.updateSubpageCount(1, 7);
        await notifier.jumpToPage(1, force: true);
        await container.pump();

        notifier.updateSubpageCount(1, 4);

        expect(_state(container).totalSubpages, 4);
      });

      test('same-page subpage navigation is accepted', () async {
        notifier.updateSubpageCount(0, 3);

        await notifier.jumpToSubpage(2, page: 0);
        await container.pump();

        expect(_state(container).subpage, 2);
      });

      test('stale-page subpage navigation is ignored', () async {
        notifier.updateSubpageCount(1, 4);
        await notifier.jumpToPage(1, force: true);
        await container.pump();
        await notifier.jumpToSubpage(2, page: 1);
        await container.pump();

        await notifier.jumpToSubpage(1, page: 0);
        await container.pump();

        expect(_state(container).subpage, 2);
      });
    });

    group('page navigation', () {
      test('back navigation lands on the last previous subpage', () async {
        notifier.updateSubpageCount(1, 5);
        await notifier.jumpToPage(1, force: true);
        await container.pump();

        // The previous page is positioned while it is out of view.
        notifier.updateSubpageCount(0, 3);
        expect(_state(container).subpagePositions[0], 2);

        await notifier.jumpToPage(0);
        await container.pump();

        expect(_state(container).page, 0);
        expect(_state(container).subpage, 2);
        expect(_state(container).ready, isTrue);
      });

      test('back navigation waits for an unknown subpage count', () async {
        await notifier.jumpToPage(1, force: true);
        await container.pump();
        await notifier.jumpToPage(0, force: true);
        await container.pump();
        expect(_state(container).ready, isFalse);

        notifier.updateSubpageCount(0, 4);
        await container.pump();

        expect(_state(container).subpage, 3);
        expect(_state(container).ready, isTrue);
      });

      test('forward navigation starts at the first subpage', () async {
        notifier.updateSubpageCount(1, 5);
        await notifier.jumpToPage(1, force: true);
        await container.pump();
        await notifier.jumpToSubpage(2, page: 1);
        await container.pump();

        notifier.updateSubpageCount(0, 3);
        await notifier.jumpToPage(0);
        await container.pump();
        expect(_state(container).subpage, 2);

        await notifier.jumpToPage(1);
        await container.pump();

        expect(_state(container).page, 1);
        expect(_state(container).subpage, 0);
      });

      test('count reports replace the position map', () async {
        notifier.updateSubpageCount(1, 5);
        await notifier.jumpToPage(1, force: true);
        await container.pump();

        final positions = _state(container).subpagePositions;
        notifier.updateSubpageCount(0, 3);

        expect(
          identical(_state(container).subpagePositions, positions),
          isFalse,
        );
        expect(positions[0], isNull);
        expect(_state(container).subpagePositions[0], 2);
      });

      test('nextPage force-jumps while measuring', () async {
        await notifier.nextPage();
        await container.pump();

        expect(_state(container).page, 1);
      });

      test('previousPage force-jumps while measuring', () async {
        await notifier.nextPage();
        await container.pump();

        await notifier.previousPage();
        await container.pump();

        expect(_state(container).page, 0);
      });
    });

    group('pending anchors', () {
      Future<void> carryTarget() async {
        notifier.updateSubpageCount(0, 3);
        notifier.updateSubpageCount(1, 5);
        await notifier.jumpToPage(1, anchor: 'target');
        await container.pump();
      }

      test('cross-page jump publishes the target anchor', () async {
        await carryTarget();

        expect(_state(container).pendingAnchor, (page: 1, anchor: 'target'));
      });

      test('settling on the target page preserves its anchor', () async {
        await carryTarget();

        await notifier.jumpToPage(1, force: true);
        await container.pump();

        expect(_state(container).pendingAnchor, (page: 1, anchor: 'target'));
      });

      test('taking an anchor for a different page preserves it', () async {
        await carryTarget();

        expect(notifier.takePendingAnchor(0), isNull);
        expect(_state(container).pendingAnchor, (page: 1, anchor: 'target'));
      });

      test('taking the target anchor consumes it', () async {
        await carryTarget();

        expect(notifier.takePendingAnchor(1), 'target');
        expect(_state(container).pendingAnchor, isNull);
      });

      test('navigating elsewhere clears the anchor', () async {
        await carryTarget();

        await notifier.jumpToPage(0);
        await container.pump();

        expect(_state(container).pendingAnchor, isNull);
      });

      test('current-page jump publishes its anchor', () async {
        notifier.updateSubpageCount(0, 3);

        await notifier.jumpToPage(0, force: true, anchor: 'target');
        await container.pump();

        expect(_state(container).pendingAnchor, (page: 0, anchor: 'target'));
      });

      test('current-page anchor can be consumed once', () async {
        notifier.updateSubpageCount(0, 3);
        await notifier.jumpToPage(0, force: true, anchor: 'target');
        await container.pump();

        expect(notifier.takePendingAnchor(0), 'target');
        expect(notifier.takePendingAnchor(0), isNull);
        expect(_state(container).pendingAnchor, isNull);
      });
    });

    group('progress', () {
      test('opening restoration does not save', () async {
        notifier.updateSubpageCount(0, 3);

        await notifier.jumpToSubpage(
          0,
          scrollId: 'opening',
          page: 0,
          restored: true,
        );
        await container.pump();

        verifyNever(
          reader.saveProgress(
            page: anyNamed('page'),
            scrollId: anyNamed('scrollId'),
            handleCompletion: anyNamed('handleCompletion'),
          ),
        );
      });

      test('subpage navigation saves its scroll id', () async {
        notifier.updateSubpageCount(0, 3);

        await notifier.jumpToSubpage(1, scrollId: 'reading', page: 0);
        await container.pump();

        verify(
          reader.saveProgress(
            page: 0,
            scrollId: 'reading',
            handleCompletion: false,
          ),
        ).called(1);
      });

      test('restored positions save after user navigation', () async {
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

        verify(
          reader.saveProgress(
            page: 1,
            scrollId: 'resume',
            handleCompletion: false,
          ),
        ).called(1);
      });
    });
  });
}

class _ReaderAdapter extends Reader {
  _ReaderAdapter(this.reader);

  final Reader reader;

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
  }) {
    return reader.saveProgress(
      page: page,
      scrollId: scrollId,
      handleCompletion: handleCompletion,
    );
  }

  @override
  Future<void> markComplete() => reader.markComplete();
}

ProviderContainer _createContainer(Reader reader) {
  final container = ProviderContainer.test(
    overrides: [
      readerProvider(
        seriesId: 1,
        chapterId: 2,
        readingListId: null,
      ).overrideWith(() => reader),
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

EpubNavigationState _state(ProviderContainer container) {
  return container.read(_provider).requireValue;
}
