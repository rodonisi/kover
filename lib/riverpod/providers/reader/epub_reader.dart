import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:html/dom.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/node_cursor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader.freezed.dart';
part 'epub_reader.g.dart';

@freezed
sealed class EpubReaderState with _$EpubReaderState {
  const EpubReaderState._();

  const factory EpubReaderState.measuring({
    required int pageIndex,
    required int totalPages,
    required PageContent page,
    required DocumentFragment subpage,
    required NodeCursor cursor,
    @Default(0) int subpageIndex,
    @Default(false) bool fromLast,
    @Default(null) String? scrollId,
    @Default([]) List<DocumentFragment> subpages,
  }) = Measuring;

  const factory EpubReaderState.display({
    required int pageIndex,
    required int totalPages,
    required PageContent page,
    required DocumentFragment subpage,
    required NodeCursor cursor,
    @Default(0) int subpageIndex,
    @Default([]) List<DocumentFragment> subpages,
  }) = Display;

  T when<T>({
    required T Function(Measuring value) measuring,
    required T Function(Display value) display,
  }) {
    return switch (this) {
      Measuring() => measuring(this as Measuring),
      Display() => display(this as Display),
    };
  }

  T? whenOrNull<T>({
    T Function(Measuring value)? measuring,
    T Function(Display value)? display,
  }) {
    return switch (this) {
      Measuring() when measuring != null => measuring(this as Measuring),
      Display() when display != null => display(this as Display),
      _ => null,
    };
  }
}

@riverpod
class EpubReader extends _$EpubReader {
  bool _processingRender = false;

  // The scroll-id to seek to on resume. Set once from the DB on the very
  // first build and cleared as soon as we reach a Display state, so that
  // subsequent page-turn rebuilds never re-trigger a seek.
  String? _resumeScrollId;

  @override
  Future<EpubReaderState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    // force rerender on settings change
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (prev, next) {
      ref.invalidateSelf(asReload: true);
    });

    final readerState = await ref.watch(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).future,
    );

    final currentPage = ref
        .watch(
          readerNavigationProvider(seriesId: seriesId, chapterId: chapterId),
        )
        .currentPage;

    if (state.value == null) {
      _resumeScrollId = readerState.bookScrollId;
    }

    final pageContent = await ref.read(
      epubPageProvider(
        chapterId: chapterId,
        page: currentPage,
      ).future,
    );

    for (final family in pageContent.fonts.entries) {
      final loader = FontLoader(family.key);
      for (final font in family.value) {
        loader.addFont(
          Future.value(ByteData.sublistView(font)),
        );
      }
      await loader.load();
      log.d('loaded font family ${family.key}');
    }

    final cursor = NodeCursor(
      root:
          pageContent.root.nodes.firstWhere((node) => node is Element)
              as Element,
    );

    final fromLast = (state.value != null)
        ? state.value!.pageIndex == currentPage + 1
        : false;

    final fragment = DocumentFragment();

    listenSelf((prev, next) {
      next.whenData((data) async {
        await data.whenOrNull(
          display: (display) async {
            _resumeScrollId = null;

            await ref
                .read(
                  readerProvider(
                    seriesId: seriesId,
                    chapterId: chapterId,
                  ).notifier,
                )
                .saveProgress(
                  page: display.pageIndex,
                  scrollId: display.subpage.paragraphScrollId(),
                );
          },
        );
      });
    });

    return EpubReaderState.measuring(
      pageIndex: currentPage,
      totalPages: readerState.totalPages,
      fromLast: fromLast,
      page: pageContent,
      subpage: fragment,
      scrollId: _resumeScrollId,
      cursor: cursor,
    );
  }

  Future<void> addElement() async {
    if (_processingRender) return;

    _processingRender = true;

    final current = await future;

    current.whenOrNull(
      measuring: (measuring) {
        if (measuring.subpageIndex + 1 < measuring.subpages.length) {
          log.d(
            'next page already measured, converting to display with subpageIndex=${measuring.subpageIndex}',
          );
          state = AsyncData(
            EpubReaderState.display(
              pageIndex: measuring.pageIndex,
              totalPages: measuring.totalPages,
              page: measuring.page,
              subpage: measuring.subpages[measuring.subpageIndex],
              subpageIndex: measuring.subpageIndex,
              subpages: measuring.subpages,
              cursor: measuring.cursor,
            ),
          );
          return;
        }

        final next = measuring.cursor.next();

        if (next == null) {
          log.d('no next element, all elements measured');
          final newSubpages = [
            ...measuring.subpages,
            if (measuring.subpage.hasChildNodes()) measuring.subpage,
          ];
          state = AsyncData(
            EpubReaderState.display(
              pageIndex: measuring.pageIndex,
              totalPages: measuring.totalPages,
              page: measuring.page,
              subpage: measuring.subpage,
              subpageIndex: measuring.subpageIndex,
              subpages: newSubpages,
              cursor: measuring.cursor,
            ),
          );
          return;
        }

        final fragment = DocumentFragment()..append(next);

        state = AsyncData(
          measuring.copyWith(
            subpage: fragment,
          ),
        );
      },
    );

    _processingRender = false;
  }

  Future<void> overflow() async {
    final current = await future;

    current.whenOrNull(
      measuring: (measuring) {
        log.d('overflow detected');

        if (measuring.cursor.splitChild()) {
          log.d('splitting child node for overflow');
          addElement();
          return;
        }

        final newSubpageNode = measuring.cursor.split();
        if (!newSubpageNode.hasChildNodes()) {
          log.d('split resulted in an empty page, re-measuring');
          state = AsyncData(
            measuring.copyWith(
              subpage: DocumentFragment(),
            ),
          );
          return;
        }
        final fragment = DocumentFragment()..append(newSubpageNode);
        final newSubpages = [...measuring.subpages, fragment];

        if (measuring.fromLast) {
          log.d('fromLast: fast forward');
          state = AsyncData(
            measuring.copyWith(
              subpages: newSubpages,
              subpageIndex: measuring.subpageIndex + 1,
              subpage: DocumentFragment(),
            ),
          );
          return; // Stay in measuring state
        }

        if (measuring.scrollId != null) {
          final resumePoint = fragment.querySelector(
            '[${HtmlConstants.scrollIdAttribute}="${measuring.scrollId}"]',
          );
          if (resumePoint == null || !resumePoint.hasChildNodes()) {
            log.d(
              'searching for resume point with scrollId: ${measuring.scrollId}, fast forward',
            );
            state = AsyncData(
              measuring.copyWith(
                subpages: newSubpages,
                subpageIndex: measuring.subpageIndex + 1,
                subpage: DocumentFragment(),
              ),
            );
            return;
          }

          resumePoint.classes.add(HtmlConstants.resumeParagraphClass);
        }

        log.d(
          'creating new display state for subpageIndex: ${measuring.subpageIndex}, total subpages: ${newSubpages.length}',
        );
        state = AsyncData(
          EpubReaderState.display(
            pageIndex: measuring.pageIndex,
            totalPages: measuring.totalPages,
            page: measuring.page,
            subpage: fragment,
            subpageIndex: newSubpages.length - 1,
            subpages: newSubpages,
            cursor: measuring.cursor,
          ),
        );
      },
    );
  }

  Future<void> nextPage() async {
    final current = await future;

    await current.whenOrNull(
      display: (display) async {
        final nextSubpageIndex = display.subpageIndex + 1;
        //  Next subpage is already measured and available
        if (nextSubpageIndex < display.subpages.length) {
          log.d('displaying pre-measured subpage $nextSubpageIndex');
          state = AsyncData(
            display.copyWith(
              subpage: display.subpages[nextSubpageIndex],
              subpageIndex: nextSubpageIndex,
            ),
          );
          return;
        }

        //  Need to measure a new subpage
        if (display.cursor.hasNext) {
          log.d('start measuring for subpage $nextSubpageIndex');
          final next = EpubReaderState.measuring(
            pageIndex: display.pageIndex,
            totalPages: display.totalPages,
            subpageIndex: nextSubpageIndex,
            subpage: DocumentFragment(),
            page: display.page,
            subpages: display.subpages,
            cursor: display.cursor,
          );

          state = const AsyncLoading();
          state = AsyncData(next);
          log.d('state updated, adding first element');
          await addElement();
          return;
        }

        // No more measured subpages and no more content to measure
        log.d('at end of chapter, moving to next chapter page');
        ref
            .read(
              readerNavigationProvider(
                seriesId: seriesId,
                chapterId: chapterId,
              ).notifier,
            )
            .nextPage();
      },
      measuring: (measuring) {
        log.d('ERROR: nextPage called while in measuring state!');
      },
    );
  }

  Future<void> previousPage() async {
    final current = await future;
    log.d('previousPage called, current state type: ${current.runtimeType}');

    // Guard: don't allow navigation while measuring
    if (current is Measuring) {
      log.d('ignoring previousPage - already measuring');
      return;
    }

    await current.whenOrNull(
      display: (display) async {
        log.d('moving to previous page');
        if (display.subpageIndex <= 0) {
          log.d('at first subpage, moving to previous chapter page');
          ref
              .read(
                readerNavigationProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                ).notifier,
              )
              .previousPage();
          return;
        }

        final prevSubpageIndex = display.subpageIndex - 1;
        final next = display.copyWith(
          subpageIndex: prevSubpageIndex,
          subpage: display.subpages[prevSubpageIndex],
        );

        state = AsyncData(next);
      },
    );
  }

  Future<void> jumpToPage(int page) async {
    log.d('Jumping to page $page');

    ref
        .read(
          readerNavigationProvider(
            seriesId: seriesId,
            chapterId: chapterId,
          ).notifier,
        )
        .jumpToPage(page);
  }
}
