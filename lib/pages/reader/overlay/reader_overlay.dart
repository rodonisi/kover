import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reader/overlay/chapter_snackbar.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures.dart';
import 'package:kover/pages/reader/overlay/reader_controls.dart';
import 'package:kover/pages/reader/overlay/reader_header.dart';
import 'package:kover/pages/reader/overlay/reader_progress.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/util/async_value.dart';

enum ShowSnackbar {
  previous,
  next,
  none,
}

class NextPageIntent extends Intent {
  const NextPageIntent();
}

class PreviousPageIntent extends Intent {
  const PreviousPageIntent();
}

class ReaderOverlay extends HookConsumerWidget {
  static const double snackbarOffset = 80.0;

  final void Function()? onNextPage;
  final void Function()? onPreviousPage;
  final void Function(int page)? onJumpToPage;
  final bool Function(int page)? isLastPage;
  final bool disableGestures;
  final int seriesId;
  final int chapterId;
  final int? readingListId;
  final Widget child;
  final Widget? endDrawer;
  final Widget? extraControls;

  const ReaderOverlay({
    super.key,
    this.onNextPage,
    this.onPreviousPage,
    this.onJumpToPage,
    this.isLastPage,
    this.endDrawer,
    this.extraControls,
    this.readingListId,
    this.disableGestures = false,
    required this.chapterId,
    required this.seriesId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final uiVisible = useState(false);
    final snackbarDismissed = useState(false);
    final showSnackbar = useState(ShowSnackbar.none);
    final provider = readerProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );

    final settings = ref.watch(
      commonReaderSettingsProvider(seriesId: seriesId),
    );
    final shouldShowSnackbar =
        showSnackbar.value != ShowSnackbar.none &&
        (!snackbarDismissed.value || uiVisible.value);

    return Async2(
      asyncValue1: ref.watch(provider),
      asyncValue2: settings,
      data: (state, settings) => Consumer(
        builder: (context, ref, _) {
          final prevChapter = ref.watch(
            prevChapterProvider(
              seriesId: seriesId,
              volumeId: state.volumeId,
              chapterId: chapterId,
              readingListId: readingListId,
            ),
          );

          final nextChapter = ref.watch(
            nextChapterProvider(
              seriesId: seriesId,
              volumeId: state.volumeId,
              chapterId: chapterId,
              readingListId: readingListId,
            ),
          );

          final reduceAnimations = ref.watch(
            themeProvider.select(
              (value) =>
                  value.whenOrNull(data: (data) => data.reduceAnimations) ??
                  const ThemeModel().reduceAnimations,
            ),
          );

          final progressFadeDuration = reduceAnimations ? 0.ms : 200.ms;
          final overlayFadeDuration = reduceAnimations ? 0.ms : 100.ms;

          ref.listen(
            readerNavigationProvider(
              seriesId: seriesId,
              chapterId: chapterId,
            ).select((state) => state.whenData((state) => state.currentPage)),
            (previous, next) {
              // Avoid showing the snackbar on initial load
              if (previous == null || previous.isLoading) return;

              next.whenData((next) {
                if (next <= 0 && prevChapter.value != null) {
                  showSnackbar.value = .previous;
                } else if (isLastPage?.call(next) ??
                    next >= state.totalPages - 1 && nextChapter.value != null) {
                  showSnackbar.value = .next;
                } else {
                  showSnackbar.value = .none;
                }
              });
            },
          );

          return Scaffold(
            endDrawerEnableOpenDragGesture: false,
            endDrawer: endDrawer,
            body: FocusableActionDetector(
              autofocus: true,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.pageDown): NextPageIntent(),
                SingleActivator(LogicalKeyboardKey.arrowRight):
                    NextPageIntent(),
                SingleActivator(LogicalKeyboardKey.pageUp):
                    PreviousPageIntent(),
                SingleActivator(LogicalKeyboardKey.arrowLeft):
                    PreviousPageIntent(),
              },
              actions: {
                NextPageIntent: CallbackAction<NextPageIntent>(
                  onInvoke: (_) => onNextPage?.call(),
                ),
                PreviousPageIntent: CallbackAction<PreviousPageIntent>(
                  onInvoke: (_) => onPreviousPage?.call(),
                ),
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Expanded(child: child),
                        if (settings.showProgressBar &&
                            state.series.format == .epub)
                          SubpageProgress(
                                seriesId: seriesId,
                                chapterId: chapterId,
                              )
                              .animate(
                                target: uiVisible.value ? 0.0 : 1.0,
                              )
                              .fadeIn(duration: progressFadeDuration)
                        else if (settings.showProgressBar)
                          ReaderProgress(
                                seriesId: seriesId,
                                chapterId: chapterId,
                              )
                              .animate(
                                target: uiVisible.value ? 0.0 : 1.0,
                              )
                              .fadeIn(duration: progressFadeDuration),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: OverlayGestures(
                      seriesId: seriesId,
                      disableGestures: disableGestures,
                      onCenterTap: () => uiVisible.value = !uiVisible.value,
                      onLeftTap: onPreviousPage,
                      onRightTap: onNextPage,
                    ),
                  ),
                  Align(
                    alignment: .topCenter,
                    child:
                        ReaderHeader(
                              seriesId: seriesId,
                              chapterId: chapterId,
                              hasDrawer: endDrawer != null,
                            )
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .show(duration: 10.ms, maintain: false)
                            .fadeIn(duration: overlayFadeDuration),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ChapterSnackbar(
                              title: l.previousChapter(
                                prevChapter.value?.title ?? '',
                              ),
                              onNavigate: () {
                                log.debug(
                                  'navigating to previous chapter',
                                  attributes: {
                                    'chapter_id':
                                        prevChapter.value?.id ?? 'null',
                                  },
                                );
                                ReaderRoute(
                                  seriesId: seriesId,
                                  chapterId: prevChapter.value!.id,
                                ).replace(context);
                              },
                              onDismiss: snackbarDismissed.value
                                  ? null
                                  : () => snackbarDismissed.value = true,
                            )
                            .animate(
                              target:
                                  shouldShowSnackbar &&
                                      showSnackbar.value == .previous
                                  ? 1.0
                                  : 0.0,
                            )
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: 100.ms)
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .moveY(
                              end: -snackbarOffset,
                              duration: overlayFadeDuration,
                            ),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ChapterSnackbar(
                              title: l.nextChapter(
                                nextChapter.value?.title ?? '',
                              ),
                              onNavigate: () {
                                log.debug(
                                  'navigating to next chapter',
                                  attributes: {
                                    'chapter_id':
                                        nextChapter.value?.id ?? 'null',
                                  },
                                );
                                ReaderRoute(
                                  seriesId: seriesId,
                                  chapterId: nextChapter.value!.id,
                                ).replace(context);
                              },
                              onDismiss: snackbarDismissed.value
                                  ? null
                                  : () => snackbarDismissed.value = true,
                            )
                            .animate(
                              target:
                                  shouldShowSnackbar &&
                                      showSnackbar.value == .next
                                  ? 1.0
                                  : 0.0,
                            )
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: overlayFadeDuration)
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .moveY(
                              end: -snackbarOffset,
                              duration: overlayFadeDuration,
                            ),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ReaderControls(
                              chapterId: chapterId,
                              seriesId: seriesId,
                              onJumpToPage: onJumpToPage,
                              extraControls: extraControls,
                            )
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: overlayFadeDuration),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
