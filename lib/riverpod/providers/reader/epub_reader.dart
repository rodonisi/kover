import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import 'package:kover/utils/reflow_engine.dart';
import 'package:kover/utils/headless_measure_pipeline.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader.freezed.dart';
part 'epub_reader.g.dart';

typedef EpubMeasureWidgetBuilder =
    Widget Function(String html, Map<String, Map<String, String>> styles);

enum EpubReflowStatus {
  measuring,
  done,
}

@freezed
sealed class EpubReflowState with _$EpubReflowState {
  const EpubReflowState._();

  const factory EpubReflowState({
    required PageContent page,
    @Default(EpubReflowStatus.measuring) EpubReflowStatus status,
    @Default(null) String? scrollId,
    @Default(null) int? resumeSubpage,
    @Default([]) List<DocumentFragment> subpages,
  }) = _EpubReflowState;
}

@riverpod
class EpubReflow extends _$EpubReflow {
  final _pipeline = HeadlessMeasurePipeline();

  // The scroll-id to seek to on resume. Set once from the DB on the very
  // first build and cleared as soon as we reach a Display state, so that
  // subsequent page-turn rebuilds never re-trigger a seek.
  String? _resumeScrollId;
  bool _measuring = false;
  late EpubMeasureWidgetBuilder _measureBuilder;
  late Duration _maxChunkDuration;
  late ReflowEngine _cursor;

  @override
  Future<EpubReflowState> build({
    required int seriesId,
    required int chapterId,
    required int page,
  }) async {
    ref.onDispose(_pipeline.dispose);

    // force rerender on settings change
    ref.listen(epubReaderSettingsProvider(seriesId: seriesId), (prev, next) {
      next.whenData((next) {
        final partialPrev = prev?.value?.copyWith(
          theme: next.theme,
        );

        // skip if the settings change doesn't affect the reflow
        if (partialPrev == next) return;

        ref.invalidateSelf(asReload: true);
      });
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

    final settings = await ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId).future,
    );

    if (settings.highlightResumePoint && _resumeScrollId != null) {
      final resumePoint = pageContent.root.querySelector(
        '[${HtmlConstants.scrollIdAttribute}="${_resumeScrollId!.cssEscaped}"]',
      );
      if (resumePoint != null && resumePoint.hasChildNodes()) {
        resumePoint.classes.add(HtmlConstants.resumeParagraphClass);
      }
    }

    _cursor = BinaryReflowEngine(root: pageContent.root.children.first);

    return EpubReflowState(
      page: pageContent,
      scrollId: _resumeScrollId,
    );
  }

  /// Runs the reflow loop synchronously against the headless
  /// [HeadlessMeasurePipeline] until the cursor is exhausted. Safe to call
  /// repeatedly; concurrent calls are coalesced and viewport changes are
  /// picked up by a running loop.
  Future<void> startReflow({
    required Size viewport,
    required double devicePixelRatio,
    required EpubMeasureWidgetBuilder measureBuilder,
    required double refreshRate,
  }) async {
    if (viewport.isEmpty) return;

    _measureBuilder = measureBuilder;
    _maxChunkDuration = Duration(milliseconds: (1000 / refreshRate).round());

    if (_measuring || !state.hasValue) return;
    _measuring = true;
    _pipeline.attach(size: viewport, devicePixelRatio: devicePixelRatio);

    try {
      // Ensure the measure widget has its data on first build; the
      // synchronous loop would otherwise outrun the async resolution.
      await ref.read(epubReaderSettingsProvider(seriesId: seriesId).future);

      if (!ref.mounted) return;
      await ref.read(customCssProvider(seriesId: seriesId).future);

      final stopwatch = Stopwatch()..start();

      while (state.value?.status != .done) {
        final maxHeight = _pipeline.viewportSize?.height ?? viewport.height;
        final bufferHtml = _cursor.buffer.outerHtml;

        if (!_pipeline.isAttached) {
          log.warning(
            'pipeline detached during reflow',
            attributes: {
              'page': page,
              'bufferLength': bufferHtml.length,
            },
          );
          return;
        }

        if (!ref.mounted) return;

        final current = await future;
        final height = _pipeline
            .measure(_measureBuilder(bufferHtml, current.page.styles))
            .height;

        // A zero-height measure for non-empty content means the measure
        // pass is silently broken; never treat it as "fits".
        if (height == 0 &&
            _cursor.buffer.hasVisibleNodes &&
            bufferHtml.isNotEmpty) {
          throw StateError(
            'measure returned zero height for non-empty buffer',
          );
        }

        if (height <= maxHeight) {
          await _addElement();
        } else {
          await _handleOverflow();
        }

        // Yield to the event loop periodically to keep the UI responsive.
        if (stopwatch.elapsed >= _maxChunkDuration) {
          stopwatch.reset();
          if (SchedulerBinding.instance.hasScheduledFrame) {
            await SchedulerBinding.instance.endOfFrame;
          } else {
            await Future<void>.delayed(0.ms);
          }
        }
        if (!ref.mounted) return;
      }
    } on MeasureTreeBuildException catch (e, stacktrace) {
      log.error(
        'measure widget failed to build',
        error: e,
        stacktrace: stacktrace,
      );
      if (ref.mounted) {
        state = AsyncError(e, stacktrace);
      }
    } finally {
      _measuring = false;
    }
  }

  Future<void> _addElement() async {
    final current = state.value;
    if (current == null || current.status == .done) return;

    final next = _cursor.addNext();
    if (next) return;

    final tail = DocumentFragment()..append(_cursor.buffer.clone(true));
    final newSubpages = [
      ...current.subpages,
      tail,
    ].where((fragment) => fragment.hasVisibleNodes).toList();

    if (newSubpages.isEmpty) {
      log.debug('no content to render, add empty page');
      newSubpages.add(DocumentFragment());
    }

    var newState = current.copyWith(
      subpages: newSubpages,
      status: .done,
    );

    newState = await _checkResumePoint(
      current: newState,
      fragment: tail,
      subpage: newSubpages.length - 1,
    );

    state = AsyncData(newState);
  }

  Future<void> _handleOverflow() async {
    final current = state.value;
    if (current == null || current.status == .done) return;

    if (_cursor.overflow()) return;

    final newSubpageNode = _cursor.commitSplit();

    final fragment = DocumentFragment()..append(newSubpageNode);
    final newSubpages = [
      ...current.subpages,
      if (fragment.hasVisibleNodes) fragment,
    ];

    var newState = current.copyWith(
      subpages: newSubpages,
    );

    newState = await _checkResumePoint(
      current: newState,
      fragment: fragment,
      subpage: newSubpages.length - 1,
    );

    state = AsyncData(newState);
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
    listenSelf((prev, next) {
      next.whenData((data) {
        if (prev?.value?.page == data.page) {
          return;
        }

        ref.listen(
          epubReflowProvider(
            seriesId: seriesId,
            chapterId: chapterId,
            page: data.page,
          ),
          (prev, next) {
            next.whenData((next) {
              if (next.status == .measuring && prev?.value?.status == .done) {
                state = AsyncData(
                  data.copyWith(
                    ready: false,
                    subpage: 0,
                    totalSubpages: next.subpages.length,
                  ),
                );
              }
            });
          },
        );
      });
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
