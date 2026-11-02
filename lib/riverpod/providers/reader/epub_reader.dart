import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader.freezed.dart';
part 'epub_reader.g.dart';

@freezed
sealed class EpubNavigationState with _$EpubNavigationState {
  const factory EpubNavigationState({
    required int page,
    required int totalPages,
    required int subpage,
    required int totalSubpages,
    @Default(false) bool ready,
    @Default(false) bool fromObserver,
    @Default(null) String? scrollId,
  }) = _EpubNavigationState;
}

@riverpod
class EpubNavigation extends _$EpubNavigation {
  final Map<int, int> _pageSubpageCounts = {};
  int? _pendingLastSubpagePage;
  var _spreads = false;
  int get _step => _spreads ? 2 : 1;

  @override
  Future<EpubNavigationState> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    final reader = await ref.read(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );

    ref.listen(
      epubReaderSettingsProvider(
        seriesId: seriesId,
      ).select((state) => state.whenData((data) => data.mode)),
      (prev, next) {
        next.whenData((mode) {
          _spreads = mode == .spreads;
        });
      },
      fireImmediately: true,
    );

    _handleNavigationProviderChanges();
    _handleProgress();

    return EpubNavigationState(
      page: reader.initialPage,
      totalPages: reader.totalPages,
      subpage: 0,
      totalSubpages: 0,
    );
  }

  void updateSubpageCount(int page, int totalSubpages) {
    _pageSubpageCounts[page] = totalSubpages;

    final current = state.value;
    if (current == null || current.page != page) return;

    final landOnLast = _pendingLastSubpagePage == page;
    if (landOnLast) {
      _pendingLastSubpagePage = null;
    }

    final subpage = landOnLast && totalSubpages > 0
        ? totalSubpages - 1
        : current.subpage;

    // Avoid redundant state writes: listeners would sync the same subpage back
    // into the page controller and start a notification loop.
    if (current.ready &&
        current.totalSubpages == totalSubpages &&
        current.subpage == subpage) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        totalSubpages: totalSubpages,
        subpage: subpage,
        ready: true,
      ),
    );
  }

  void _handleProgress() {
    listenSelf((prev, next) {
      next.whenData((data) async {
        final isSamePosition =
            prev?.value?.page == data.page &&
            prev?.value?.subpage == data.subpage &&
            prev?.value?.scrollId == data.scrollId;

        if (!data.ready || isSamePosition) return;

        final isLastSubpage = _spreads
            ? data.subpage >= data.totalSubpages - 2
            : data.subpage >= data.totalSubpages - 1;

        if (data.page >= data.totalPages - 1 && isLastSubpage) {
          await ref
              .read(
                readerProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                  readingListId: readingListId,
                ).notifier,
              )
              .markComplete();
          return;
        }

        try {
          final reader = ref.read(
            readerProvider(
              seriesId: seriesId,
              chapterId: chapterId,
              readingListId: readingListId,
            ).notifier,
          );
          await reader.saveProgress(
            page: data.page,
            scrollId: data.scrollId,
            handleCompletion: false,
          );
        } catch (e, stacktrace) {
          log.error(
            'handleProgress save failed',
            error: e,
            stacktrace: stacktrace,
          );
        }
      });
    });
  }

  void _handleNavigationProviderChanges() {
    ref.listen(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).select((state) => state.whenData((state) => state.currentPage)),
      (prev, next) async {
        next.whenData(
          (next) async {
            final current = await future;
            final cachedCount = _pageSubpageCounts[next];
            final landOnLast = _pendingLastSubpagePage == next;
            final subpage = landOnLast && cachedCount != null && cachedCount > 0
                ? cachedCount - 1
                : 0;

            if (!landOnLast || cachedCount != null) {
              _pendingLastSubpagePage = null;
            }

            state = AsyncData(
              current.copyWith(
                page: next,
                subpage: subpage,
                totalSubpages: cachedCount ?? 0,
                ready: cachedCount != null,
                fromObserver: false,
                scrollId: null,
              ),
            );
          },
        );
      },
      fireImmediately: true,
    );
    ref
        .read(
          readerNavigationProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            readingListId: readingListId,
          ).notifier,
        )
        .handleCompletion(false);
  }

  Future<void> jumpToPage(int page, {bool force = false}) async {
    final current = await future;

    if ((!current.ready && !force) || page >= current.totalPages || page < 0) {
      return;
    }

    if (current.page - page == 1) {
      _pendingLastSubpagePage = page;
    } else if (page != current.page) {
      _pendingLastSubpagePage = null;
    }

    await ref
        .read(
          readerNavigationProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            readingListId: readingListId,
          ).notifier,
        )
        .jumpToPage(page);
  }

  Future<void> jumpToSubpage(
    int subpage, {
    bool fromObserver = false,
    String? scrollId,
    int? page,
  }) async {
    final current = await future;

    if (page != null && current.page != page) return;
    if (!current.ready) return;

    if (subpage < 0) {
      await jumpToPage(current.page - 1);
      return;
    }

    if (subpage >= current.totalSubpages) {
      await jumpToPage(current.page + 1);
      return;
    }

    state = AsyncData(
      current.copyWith(
        subpage: subpage,
        fromObserver: fromObserver,
        scrollId: scrollId,
      ),
    );
  }

  Future<void> nextPage() async {
    final current = await future;

    if (!current.ready) {
      await jumpToPage(current.page + 1, force: true);
      return;
    }

    await jumpToSubpage(current.subpage + _step);
  }

  Future<void> previousPage() async {
    final current = await future;

    if (!current.ready) {
      await jumpToPage(current.page - 1, force: true);
      return;
    }

    await jumpToSubpage(current.subpage - _step);
  }
}
