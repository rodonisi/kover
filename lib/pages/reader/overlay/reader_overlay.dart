import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/overlay/reader_controls.dart';
import 'package:kover/pages/reader/overlay/reader_header.dart';
import 'package:kover/pages/reader/toc_drawer.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/async_value.dart';

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
  final int seriesId;
  final int chapterId;
  final Widget child;

  const ReaderOverlay({
    super.key,
    this.onNextPage,
    this.onPreviousPage,
    this.onJumpToPage,
    this.isLastPage,
    required this.chapterId,
    required this.seriesId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiVisible = useState(false);
    final showSnackbar = useState(ShowSnackbar.none);
    final provider = readerProvider(seriesId: seriesId, chapterId: chapterId);

    return Async(
      asyncValue: ref.watch(provider),
      data: (state) => Consumer(
        builder: (context, ref, _) {
          final prevChapter = ref.watch(
            prevChapterProvider(
              seriesId: seriesId,
              volumeId: state.volumeId,
              chapterId: chapterId,
            ),
          );

          final nextChapter = ref.watch(
            nextChapterProvider(
              seriesId: seriesId,
              volumeId: state.volumeId,
              chapterId: chapterId,
            ),
          );

          ref.listen(
            readerNavigationProvider(
              seriesId: seriesId,
              chapterId: chapterId,
            ).select((state) => state.currentPage),
            (previous, next) {
              if (next <= 0 && prevChapter.value != null) {
                showSnackbar.value = .previous;
              } else if (isLastPage?.call(next) ??
                  next >= state.totalPages - 1 && nextChapter.value != null) {
                showSnackbar.value = .next;
              } else {
                showSnackbar.value = .none;
              }
            },
          );

          return Scaffold(
            endDrawerEnableOpenDragGesture: true,
            endDrawer: TocDrawer(
              seriesId: seriesId,
              chapterId: chapterId,
            ),
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
                        if (state.series.format == .epub)
                          SubpageProgress(
                            seriesId: seriesId,
                            chapterId: chapterId,
                          )
                        else
                          ReaderProgress(
                                seriesId: seriesId,
                                chapterId: chapterId,
                              )
                              .animate(
                                target: uiVisible.value ? 0.0 : 1.0,
                              )
                              .fadeIn(duration: 200.ms),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: GestureDetector(
                            behavior: .translucent,
                            onTap: onPreviousPage,
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: GestureDetector(
                            behavior: .translucent,
                            onTap: () => uiVisible.value = !uiVisible.value,
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: GestureDetector(
                            behavior: .translucent,
                            onTap: onNextPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: .topCenter,
                    child:
                        ReaderHeader(
                              seriesId: seriesId,
                              chapterId: chapterId,
                            )
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .show(duration: 10.ms, maintain: false)
                            .fadeIn(duration: 100.ms),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ChapterSnackbar(
                              title: 'Previous: ${prevChapter.value?.title}',
                              onNavigate: () {
                                log.d(
                                  'Navigating to prev chapter ${prevChapter.value}',
                                );
                                ReaderRoute(
                                  seriesId: seriesId,
                                  chapterId: prevChapter.value!.id,
                                ).replace(context);
                              },
                            )
                            .animate(
                              target: showSnackbar.value == .previous
                                  ? 1.0
                                  : 0.0,
                            )
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: 100.ms)
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .moveY(end: -snackbarOffset, duration: 100.ms),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ChapterSnackbar(
                              title: 'Next: ${nextChapter.value?.title}',
                              onNavigate: () {
                                log.d(
                                  'Navigating to next chapter ${nextChapter.value}',
                                );
                                ReaderRoute(
                                  seriesId: seriesId,
                                  chapterId: nextChapter.value!.id,
                                ).replace(context);
                              },
                            )
                            .animate(
                              target: showSnackbar.value == .next ? 1.0 : 0.0,
                            )
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: 100.ms)
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .moveY(end: -snackbarOffset, duration: 100.ms),
                  ),
                  Align(
                    alignment: .bottomCenter,
                    child:
                        ReaderControls(
                              chapterId: chapterId,
                              seriesId: seriesId,
                              onJumpToPage: onJumpToPage,
                            )
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .show(duration: 10.ms, maintain: false)
                            .fade(duration: 100.ms),
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

class ReaderProgress extends ConsumerWidget {
  final int seriesId;
  final int? chapterId;

  const ReaderProgress({
    super.key,
    required this.seriesId,
    this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(
      readerNavigationProvider(seriesId: seriesId, chapterId: chapterId ?? 0),
    );

    final progress = navState.currentPage / (navState.totalPages - 1);

    return LinearProgressIndicator(
      value: progress,
    );
  }
}

class SubpageProgress extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  const SubpageProgress({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = ref.watch(
      epubNavigationProvider(seriesId: seriesId, chapterId: chapterId),
    );

    final progress = reader.whenOrNull(
      data: (data) => (data.page + 1) / data.totalPages,
    );

    final subpageProgress = reader.whenOrNull(
      data: (data) => (data.subpage + 0) / data.totalSubpages,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final stepWidth =
        reader.whenOrNull(
          data: (data) => screenWidth / data.totalPages,
        ) ??
        0.0;
    final offset = reader.whenOrNull(
      data: (data) => stepWidth * data.page,
    );

    return SizedBox(
      height: 4.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: LinearProgressIndicator(
              value: progress,
            ),
          ),
          Positioned(
            left: offset,
            child: SizedBox(
              width: stepWidth,
              child: LinearProgressIndicator(
                value: subpageProgress,
                backgroundColor: theme.colorScheme.tertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChapterSnackbar extends StatelessWidget {
  final String title;
  final void Function()? onNavigate;
  const ChapterSnackbar({super.key, required this.title, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                overflow: .ellipsis,
              ),
            ),
            FilledButton(
              onPressed: onNavigate,
              child: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }
}
