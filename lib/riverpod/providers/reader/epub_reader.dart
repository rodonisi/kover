import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader.freezed.dart';
part 'epub_reader.g.dart';

typedef EpubMeasureWidgetBuilder = Widget Function(
  String html,
  Map<String, Map<String, String>> styles,
);

@freezed
sealed class EpubNavigationState with _$EpubNavigationState {
  const factory EpubNavigationState({
    required int page,
    required int totalPages,
    required int subpage,
    required int totalSubpages,
    @Default(false) bool ready,
    @Default(false) bool fromObserver,
  }) = _EpubNavigationState;
}

@riverpod
class EpubNavigation extends _$EpubNavigation {
  var _fromLastSubpage = false;
  final _resumed = false;
  final _wasAheadReflow = false;
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

  void updateSubpageCount(int totalSubpages) {
    final current = state.value;
    if (current == null) return;

    // Avoid redundant state writes: listeners would sync the same subpage back
    // into the page controller and start a notification loop.
    if (current.ready && current.totalSubpages == totalSubpages) return;

    state = AsyncData(
      current.copyWith(
        totalSubpages: totalSubpages,
        ready: true,
      ),
    );
  }

  void _handleProgress() {
    listenSelf((prev, next) {
      next.whenData((data) async {
        final isSamePosition =
            prev?.value?.page == data.page &&
            prev?.value?.subpage == data.subpage;

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

            if (prev != null &&
                prev.hasValue &&
                (next - prev.value!).abs() > 1) {
              _fromLastSubpage = false;
            }

            state = AsyncData(
              current.copyWith(
                page: next,
                subpage: 0,
                ready: false,
                fromObserver: false,
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

  Future<void> jumpToPage(int page) async {
    final current = await future;

    if (!current.ready || page >= current.totalPages || page < 0) return;

    if (current.page - page == 1) {
      _fromLastSubpage = true;
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

  Future<void> jumpToSubpage(int subpage, {bool fromObserver = false}) async {
    final current = await future;

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
      ),
    );
  }

  Future<void> nextPage() async {
    final current = await future;
    await jumpToSubpage(current.subpage + _step);
  }

  Future<void> previousPage() async {
    final current = await future;
    await jumpToSubpage(current.subpage - _step);
  }
}

@freezed
sealed class EpubReaderSubpageState with _$EpubReaderSubpageState {
  const factory EpubReaderSubpageState({
    required EpubNavigationState navigation,
    required EpubReaderMode mode,
    required double paragraphSpacing,
    required bool reverse,
    required bool navigationGesturesEnabled,
    required bool reduceAnimations,
  }) = _EpubReaderSubpageState;
}

@riverpod
Future<EpubReaderSubpageState> epubReaderSubpage(
  Ref ref, {
  required int seriesId,
  required int chapterId,
  required int? readingListId,
  required int page,
}) async {
  final navigationFuture = ref.watch(
    epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final epubSettingsFuture = ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId).selectAsync(
      (value) => (value.mode, value.paragraphSpacing),
    ),
  );
  final commonSettingsFuture = ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId).selectAsync(
      (value) => (value.navigationGersturesEnabled, value.readDirection),
    ),
  );
  final reduceAnimationsFuture = ref.watch(
    themeProvider.selectAsync((value) => value.reduceAnimations),
  );

  final navigation = await navigationFuture;
  final (mode, paragraphSpacing) = await epubSettingsFuture;
  final (navigationGestures, readDirection) = await commonSettingsFuture;
  final reduceAnimations = await reduceAnimationsFuture;

  return EpubReaderSubpageState(
    navigation: navigation,
    mode: mode,
    paragraphSpacing: paragraphSpacing,
    reverse: readDirection == .rightToLeft,
    navigationGesturesEnabled: navigationGestures,
    reduceAnimations: reduceAnimations,
  );
}
