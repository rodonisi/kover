import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:html/dom.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:kover/utils/extensions/string.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/element_cursor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader.freezed.dart';
part 'epub_reader.g.dart';

enum EpubReflowStatus {
  measuring,
  done,
}

@freezed
sealed class EpubReflowState with _$EpubReflowState {
  const EpubReflowState._();

  const factory EpubReflowState({
    required PageContent page,
    @Default(null) DocumentFragment? buffer,
    @Default(EpubReflowStatus.measuring) EpubReflowStatus status,
    @Default(null) String? scrollId,
    @Default(null) int? resumeSubpage,
    @Default([]) List<DocumentFragment> subpages,
  }) = _EpubReflowState;
}

@riverpod
class EpubReflow extends _$EpubReflow {
  bool _processingRender = false;

  // The scroll-id to seek to on resume. Set once from the DB on the very
  // first build and cleared as soon as we reach a Display state, so that
  // subsequent page-turn rebuilds never re-trigger a seek.
  String? _resumeScrollId;
  late ElementCursor _cursor;

  @override
  Future<EpubReflowState> build({
    required int seriesId,
    required int chapterId,
    required int page,
  }) async {
    // force rerender on settings change
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (prev, next) {
      ref.invalidate(
        readerProvider(seriesId: seriesId, chapterId: chapterId),
        asReload: true,
      );
      ref.invalidateSelf(asReload: true);
    });

    final readerState = await ref.read(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).future,
    );

    if (page == readerState.initialPage) {
      _resumeScrollId = readerState.bookScrollId;
    }

    if (!ref.mounted) throw StateError('epubReflowProvider disposed');
    final pageContent = await ref.read(
      epubPageProvider(
        chapterId: chapterId,
        page: page,
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
    }

    _cursor = ElementCursor(root: pageContent.root.children.first);

    return EpubReflowState(
      page: pageContent,
      scrollId: _resumeScrollId,
    );
  }

  Future<void> addElement({bool force = false}) async {
    final current = await future;
    if (!force && (_processingRender || current.status == .done)) return;

    try {
      _processingRender = true;

      final next = _cursor.addNext();

      if (next == null) {
        final newSubpages = [
          ...current.subpages,
          ?current.buffer,
        ].where((fragment) => fragment.hasVisibleNodes).toList();

        if (newSubpages.isEmpty) {
          log.debug('no content to render, add empty page');
          newSubpages.add(DocumentFragment());
        }

        var newState = current.copyWith(
          subpages: newSubpages,
          status: .done,
        );

        if (current.buffer != null) {
          newState = await _checkResumePoint(
            current: newState,
            fragment: current.buffer!,
            subpage: newSubpages.length - 1,
          );
        }

        state = AsyncData(newState);
        return;
      }

      state = AsyncData(
        current.copyWith(
          buffer: DocumentFragment()..append(next),
        ),
      );
    } finally {
      _processingRender = false;
    }
  }

  Future<void> overflow() async {
    if (_processingRender) return;
    _processingRender = true;
    try {
      _processingRender = true;

      final current = await future;

      if (current.status == .done) return;

      if (_cursor.splitChild()) {
        await addElement(force: true);
        return;
      }

      final newSubpageNode = _cursor.commitSplit();

      final fragment = DocumentFragment()..append(newSubpageNode);
      final newSubpages = [
        ...current.subpages,
        if (fragment.hasVisibleNodes) fragment,
      ];
      var newState = current.copyWith(
        subpages: newSubpages,
        buffer: null,
      );

      newState = await _checkResumePoint(
        current: newState,
        fragment: fragment,
        subpage: newSubpages.length - 1,
      );

      state = AsyncData(newState);
    } finally {
      _processingRender = false;
    }
  }

  Future<EpubReflowState> _checkResumePoint({
    required EpubReflowState current,
    required DocumentFragment fragment,
    required int subpage,
  }) async {
    EpubReflowState? newState;
    if (current.scrollId != null) {
      try {
        final resumePoint = fragment.querySelector(
          '[${HtmlConstants.scrollIdAttribute}="${current.scrollId!.cssEscaped}"]',
        );
        if (resumePoint != null && resumePoint.hasChildNodes()) {
          log.info(
            'found resume point',
            attributes: {
              'scroll_id': current.scrollId,
            },
          );

          final settings = await ref.read(
            epubReaderSettingsProvider(seriesId: seriesId).future,
          );
          if (settings.highlightResumePoint) {
            resumePoint.classes.add(HtmlConstants.resumeParagraphClass);
          }

          newState = current.copyWith(
            scrollId: null,
            resumeSubpage: subpage,
          );
        }
      } catch (e, stacktrace) {
        log.error(
          'failed to find resume point in new subpage',
          error: e,
          stacktrace: stacktrace,
        );
      }
    }
    return newState ?? current;
  }
}

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
  ProviderSubscription<AsyncValue<EpubReflowState>>? _reflowSub;
  var _fromLastSubpage = false;
  var _resumed = false;
  var _wasAheadReflow = false;

  @override
  Future<EpubNavigationState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    final reader = await ref.read(
      readerProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    _handleNavigationProviderChanges();
    _handleProgress();
    _handleSettingsChanges();

    return EpubNavigationState(
      page: reader.initialPage,
      totalPages: reader.totalPages,
      subpage: 0,
      totalSubpages: 0,
    );
  }

  void _handleSettingsChanges() {
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (
      prev,
      next,
    ) async {
      final current = await future;

      _resumed = false;
      state = AsyncData(
        current.copyWith(ready: false, subpage: 0),
      );
    });
  }

  void _handleProgress() {
    listenSelf((prev, next) {
      next.whenData((data) async {
        final reflow = await ref.read(
          epubReflowProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            page: data.page,
          ).future,
        );

        final isAheadReflow = reflow.subpages.length <= data.subpage;
        final isSamePosition =
            _wasAheadReflow == isAheadReflow &&
            prev?.value?.page == data.page &&
            prev?.value?.subpage == data.subpage;
        _wasAheadReflow = isAheadReflow;

        if (!data.ready || isAheadReflow || isSamePosition) return;

        final scrollId = reflow.subpages[data.subpage].paragraphScrollId();

        if (reflow.status == .done &&
            data.page >= data.totalPages - 1 &&
            data.subpage >= data.totalSubpages - 1) {
          await ref
              .read(
                readerProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                ).notifier,
              )
              .markComplete();
          return;
        }

        await ref
            .read(
              readerProvider(
                seriesId: seriesId,
                chapterId: chapterId,
              ).notifier,
            )
            .saveProgress(
              page: data.page,
              scrollId: scrollId,
              handleCompletion: false,
            );
      });
    });
  }

  void _handleNavigationProviderChanges() {
    ref.listen(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
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

            _handleReflowChanges(
              seriesId: seriesId,
              chapterId: chapterId,
              page: next,
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
          ).notifier,
        )
        .handleCompletion(false);
  }

  void _handleReflowChanges({
    required int seriesId,
    required int chapterId,
    required int page,
  }) {
    _reflowSub?.close();
    _reflowSub = ref.listen(
      epubReflowProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: page,
      ),
      (prev, next) {
        next.whenData((data) async {
          final current = await future;

          if (_fromLastSubpage) {
            if (data.status == .done) {
              state = AsyncData(
                current.copyWith(
                  subpage: data.subpages.length - 1,
                  totalSubpages: data.subpages.length,
                  ready: true,
                ),
              );
              _fromLastSubpage = false;
            }
            return;
          }

          if (!_resumed && data.resumeSubpage != null) {
            _resumed = true;
            state = AsyncData(
              current.copyWith(
                subpage: data.resumeSubpage!,
                totalSubpages: data.subpages.length,
                ready: true,
              ),
            );
            return;
          }

          state = AsyncData(
            current.copyWith(
              totalSubpages: data.subpages.length,
              ready: data.status == .done || data.scrollId == null,
            ),
          );
        });
      },
      fireImmediately: true,
    );
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
          ).notifier,
        )
        .jumpToPage(page);
  }

  Future<void> jumpToSubpage(int subpage, {bool fromObserver = false}) async {
    final current = await future;

    if (!current.ready) return;

    final reflow = await ref.read(
      epubReflowProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: current.page,
      ).future,
    );

    if (subpage < 0) {
      await jumpToPage(current.page - 1);
      return;
    }

    if (reflow.status == .done && subpage >= reflow.subpages.length) {
      await jumpToPage(current.page + 1);
      return;
    }

    state = AsyncData(
      current.copyWith(
        subpage: subpage,
        ready: reflow.status == .done || subpage < reflow.subpages.length,
        fromObserver: fromObserver,
      ),
    );
  }

  Future<void> nextPage() async {
    final current = await future;
    await jumpToSubpage(current.subpage + 1);
  }

  Future<void> previousPage() async {
    final current = await future;
    await jumpToSubpage(current.subpage - 1);
  }
}
