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
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/node_cursor.dart';
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
    required DocumentFragment buffer,
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
  late NodeCursor _cursor;

  @override
  Future<EpubReflowState> build({
    required int seriesId,
    required int chapterId,
    required int page,
  }) async {
    // force rerender on settings change
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (prev, next) {
      ref.invalidateSelf(asReload: true);
    });

    final readerState = await ref.read(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).future,
    );

    if (state.value == null && page == readerState.initialPage) {
      _resumeScrollId = readerState.bookScrollId;
    }

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
      log.d('loaded font family ${family.key}');
    }

    _cursor = NodeCursor(
      root:
          pageContent.root.nodes.firstWhere((node) => node is Element)
              as Element,
    );

    return EpubReflowState(
      page: pageContent,
      scrollId: _resumeScrollId,
      buffer: DocumentFragment(),
    );
  }

  Future<void> addElement() async {
    if (_processingRender) return;

    try {
      _processingRender = true;

      final current = await future;

      final next = _cursor.next();

      if (next == null) {
        log.d('no next element, all elements measured');
        final newSubpages = [
          ...current.subpages,
          if (current.buffer.hasChildNodes()) current.buffer,
        ];
        state = AsyncData(
          current.copyWith(
            subpages: newSubpages,
            status: .done,
          ),
        );
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
    final current = await future;

    log.d('overflow detected');

    if (_cursor.splitChild()) {
      log.d('splitting child node for overflow');
      await addElement();
      return;
    }

    final newSubpageNode = _cursor.split();
    if (!newSubpageNode.hasChildNodes()) {
      log.d('split resulted in an empty page, re-measuring');

      state = AsyncData(
        current.copyWith(
          buffer: DocumentFragment(),
        ),
      );
      return;
    }

    final fragment = DocumentFragment()..append(newSubpageNode);
    final newSubpages = [...current.subpages, fragment];
    var newState = current.copyWith(
      subpages: newSubpages,
      buffer: DocumentFragment(),
    );

    if (current.scrollId != null) {
      final resumePoint = fragment.querySelector(
        '[${HtmlConstants.scrollIdAttribute}="${current.scrollId}"]',
      );
      if (resumePoint != null && resumePoint.hasChildNodes()) {
        log.d(
          'found resume point with scrollId: ${current.scrollId}',
        );

        resumePoint.classes.add(HtmlConstants.resumeParagraphClass);
        newState = newState.copyWith(
          scrollId: null,
          resumeSubpage: newSubpages.length - 1,
        );
      }
    }

    state = AsyncData(newState);
  }
}

@freezed
sealed class EpubNavigationState with _$EpubNavigationState {
  const factory EpubNavigationState({
    required int page,
    required int totalPages,
    required int subpage,
    @Default(false) bool ready,
  }) = _EpubNavigationState;
}

@riverpod
class EpubNavigation extends _$EpubNavigation {
  ProviderSubscription<AsyncValue<EpubReflowState>>? _reflowSub;
  var _fromLastSubpage = false;
  var _resumed = false;

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
    );
  }

  void _handleSettingsChanges() {
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (prev, next) {
      _resumed = false;
      ref.invalidateSelf(asReload: true);
    });
  }

  void _handleProgress() {
    listenSelf((prev, next) {
      next.whenData((data) async {
        if (!data.ready) return;

        final reflow = await ref.read(
          epubReflowProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            page: data.page,
          ).future,
        );

        final scrollId = reflow.subpages[data.subpage].paragraphScrollId();

        await ref
            .read(
              readerProvider(seriesId: seriesId, chapterId: chapterId).notifier,
            )
            .saveProgress(page: data.page, scrollId: scrollId);
      });
    });
  }

  void _handleNavigationProviderChanges() {
    ref.listen(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).select((state) => state.currentPage),
      (prev, next) {
        final current = state.value;
        if (current == null) return;

        if (prev != null && (next - prev).abs() > 1) {
          _fromLastSubpage = false;
        }

        state = AsyncData(
          current.copyWith(
            page: next,
            subpage: 0,
            ready: false,
          ),
        );

        _handleReflowChanges(
          seriesId: seriesId,
          chapterId: chapterId,
          page: next,
        );
      },
      fireImmediately: true,
    );
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
        next.whenData((data) {
          final current = state.value;
          if (current == null) return;

          if (_fromLastSubpage) {
            if (data.status == .done) {
              state = AsyncData(
                current.copyWith(
                  subpage: data.subpages.length - 1,
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
              current.copyWith(subpage: data.resumeSubpage!, ready: true),
            );
            return;
          }

          state = AsyncData(
            current.copyWith(
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

    if (!current.ready) return;

    ref
        .read(
          readerNavigationProvider(
            seriesId: seriesId,
            chapterId: chapterId,
          ).notifier,
        )
        .jumpToPage(page);
  }

  Future<void> jumpToSubpage(int subpage) async {
    final current = await future;

    if (!current.ready) return;

    final reflow = await ref.read(
      epubReflowProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: current.page,
      ).future,
    );

    state = AsyncData(
      current.copyWith(
        subpage: subpage,
        ready: reflow.status == .done || subpage < reflow.subpages.length,
      ),
    );
  }

  Future<void> nextPage() async {
    final current = await future;
    final reflow = await ref.read(
      epubReflowProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: current.page,
      ).future,
    );

    if (reflow.status == .measuring &&
        current.subpage >= reflow.subpages.length) {
      return;
    }

    if (current.subpage < reflow.subpages.length - 1) {
      await jumpToSubpage(current.subpage + 1);
    } else if (current.page < current.totalPages - 1) {
      await jumpToPage(current.page + 1);
    }
  }

  Future<void> previousPage() async {
    final current = await future;
    if (current.subpage > 0) {
      await jumpToSubpage(current.subpage - 1);
    } else if (current.page > 0) {
      _fromLastSubpage = true;
      await jumpToPage(current.page - 1);
    }
  }
}
