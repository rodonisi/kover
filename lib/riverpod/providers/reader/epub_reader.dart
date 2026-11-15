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
class EpubSubpagePosition({required final int subpage, final String? scrollId})
    with _$EpubSubpagePosition;

@freezed
class EpubNavigationState({
  required final int page,
  required final int totalPages,
  final Map<int, EpubSubpagePosition> subpagePositions = const {},
  final Map<int, int> subpageCounts = const {},
  final bool ready = false,
  final ({int page, String anchor})? pendingAnchor,
}) with _$EpubNavigationState {
  int get subpage => subpagePositions[page]?.subpage ?? 0;
  String? get scrollId => subpagePositions[page]?.scrollId;
  int get totalSubpages => subpageCounts[page] ?? 0;
}

@riverpod
class EpubNavigation extends _$EpubNavigation {
  int? _pendingLastSubpagePage;
  var _spreads = false;
  var _positionRestored = false;
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
    );
  }

  void updateSubpageCount(int page, int totalSubpages) {
    final current = state.requireValue;

    final subpageCounts = {...current.subpageCounts, page: totalSubpages};
    final subpagePositions = {...current.subpagePositions};

    if ((page < current.page || page == _pendingLastSubpagePage) &&
        totalSubpages > 0) {
      subpagePositions[page] = EpubSubpagePosition(subpage: totalSubpages - 1);
    }

    if (current.ready &&
        current.subpageCounts == subpageCounts &&
        current.subpagePositions == subpagePositions) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        subpageCounts: subpageCounts,
        subpagePositions: subpagePositions,
        ready: subpageCounts.containsKey(current.page),
      ),
    );
  }

  void restorePosition({
    required int page,
    required int subpage,
    String? scrollId,
  }) {
    updateSubpagePosition(page: page, subpage: subpage, scrollId: scrollId);
    if (page == state.value?.page) _positionRestored = true;
  }

  void updateSubpagePosition({
    required int page,
    required int subpage,
    String? scrollId,
  }) {
    final current = state.requireValue;

    final subpagePositions = {
      ...current.subpagePositions,
      page: EpubSubpagePosition(subpage: subpage, scrollId: scrollId),
    };

    state = AsyncData(
      current.copyWith(
        subpagePositions: subpagePositions,
      ),
    );
  }

  void _handleProgress() {
    listenSelf((prev, next) {
      next.whenData((data) async {
        // Opening a chapter restores its saved position. That restoration is
        // not a reading action and must not rewrite progress.
        if (!_positionRestored || data.scrollId == null) return;

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
          await ref
              .read(
                readerProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                  readingListId: readingListId,
                ).notifier,
              )
              .saveProgress(
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
            final cachedCount = current.subpageCounts[next];
            final isSequentialBack = current.page - next == 1;

            final subpagePositions = {...current.subpagePositions};
            if (current.page != next && !isSequentialBack) {
              // Forward and non-sequential jumps always start at the top of
              // the target page.
              subpagePositions[next] = EpubSubpagePosition(subpage: 0);
            }

            final pendingAnchor = current.pendingAnchor?.page == next
                ? current.pendingAnchor
                : null;

            state = AsyncData(
              current.copyWith(
                page: next,
                subpagePositions: subpagePositions,
                ready: cachedCount != null,
                pendingAnchor: pendingAnchor,
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

  Future<void> jumpToPage(
    int page, {
    bool force = false,
    String? anchor,
  }) async {
    final current = await future;

    if ((!current.ready && !force) || page >= current.totalPages || page < 0) {
      _clearPendingAnchor();
      return;
    }

    if (page != current.page) {
      _positionRestored = true;
    }

    final pendingAnchor = anchor != null
        ? (page: page, anchor: anchor)
        : current.pendingAnchor?.page == page
        ? current.pendingAnchor
        : null;

    if (anchor != null) {
      _pendingLastSubpagePage = null;
    } else if (current.page - page == 1 &&
        !current.subpageCounts.containsKey(page)) {
      // The count is not known yet, so it cannot have been pre-positioned to
      // the last subpage. Remember the target and resolve it on measurement.
      _pendingLastSubpagePage = page;
    } else if (page != current.page) {
      _pendingLastSubpagePage = null;
    }

    if (pendingAnchor != current.pendingAnchor) {
      state = AsyncData(current.copyWith(pendingAnchor: pendingAnchor));
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

  /// Returns the pending anchor for [page], clearing it so it is applied once.
  String? takePendingAnchor(int page) {
    final current = state.value;
    if (current == null ||
        current.page != page ||
        current.pendingAnchor?.page != page) {
      return null;
    }

    final anchor = current.pendingAnchor!.anchor;
    state = AsyncData(current.copyWith(pendingAnchor: null));
    return anchor;
  }

  void _clearPendingAnchor() {
    final current = state.value;
    if (current == null || current.pendingAnchor == null) return;

    state = AsyncData(current.copyWith(pendingAnchor: null));
  }

  Future<void> _jumpToSubpage(int subpage) async {
    final current = state.value ?? await future;
    if (!current.ready) return;
    _positionRestored = true;

    if (subpage < 0) {
      await jumpToPage(current.page - 1);
      return;
    }

    if (subpage >= current.totalSubpages) {
      await jumpToPage(current.page + 1);
      return;
    }

    final subpagePositions = {
      ...current.subpagePositions,
      current.page: EpubSubpagePosition(subpage: subpage),
    };

    final next = current.copyWith(
      subpagePositions: subpagePositions,
      pendingAnchor: current.pendingAnchor?.page == current.page
          ? null
          : current.pendingAnchor,
    );

    if (next == current) return;

    state = AsyncData(next);
  }

  Future<void> nextPage() async {
    final current = state.value ?? await future;

    if (!current.ready) {
      await jumpToPage(current.page + 1, force: true);
      return;
    }

    await _jumpToSubpage(current.subpage + _step);
  }

  Future<void> previousPage() async {
    final current = state.value ?? await future;

    if (!current.ready) {
      await jumpToPage(current.page - 1, force: true);
      return;
    }

    await _jumpToSubpage(current.subpage - _step);
  }
}
