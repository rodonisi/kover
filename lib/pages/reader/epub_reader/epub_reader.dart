import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/epub_measure_root.dart';
import 'package:kover/pages/reader/epub_reader/epub_toc_drawer.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content.dart';
import 'package:kover/pages/reader/epub_reader/epub_theme_override.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';

class EpubReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int? readingListId;

  const EpubReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
    this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = useState(false);
    final nav = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final commonSettings = ref.watch(
      commonReaderSettingsProvider(seriesId: seriesId),
    );

    final reduceAnimations = ref.watch(
      themeProvider.select(
        (value) =>
            value.whenOrNull(
              data: (data) => data.reduceAnimations,
            ) ??
            const ThemeModel().reduceAnimations,
      ),
    );

    return Async(
      asyncValue: commonSettings,
      data: (commonSettings) => ReaderOverlay(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
        disableGestures: hasSelection.value,
        onNextPage: () {
          commonSettings.readDirection == .leftToRight
              ? ref.read(nav.notifier).nextPage()
              : ref.read(nav.notifier).previousPage();
        },
        onPreviousPage: () {
          commonSettings.readDirection == .leftToRight
              ? ref.read(nav.notifier).previousPage()
              : ref.read(nav.notifier).nextPage();
        },
        onJumpToPage: (page) {
          ref.read(nav.notifier).jumpToPage(page);
        },
        endDrawer: EpubTocDrawer(
          seriesId: seriesId,
          chapterId: chapterId,
        ),
        child: EpubThemeOverride(
          seriesId: seriesId,
          child: Async(
            asyncValue: ref.watch(nav),
            data: (navState) => HookConsumer(
              builder: (context, ref, child) {
                final controller = usePageController(
                  initialPage: navState.page,
                );

                ref.listen(nav, (
                  previous,
                  next,
                ) async {
                  next.whenData((next) async {
                    final previousPage = previous?.value?.page;
                    final nextPage = next.page;

                    if (nextPage == previousPage) return;

                    if (controller.hasClients &&
                        controller.page?.round() != nextPage) {
                      final isSequential =
                          previousPage != null &&
                          (nextPage - previousPage).abs() == 1;

                      isSequential && !reduceAnimations
                          ? controller.animateToPage(
                              nextPage,
                              duration: LayoutConstants.pageSlideDuration,
                              curve: Curves.easeInOut,
                            )
                          : controller.jumpToPage(nextPage);
                    }
                  });
                });

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Offstage(
                        offstage: !navState.ready,
                        child: PageView.builder(
                          controller: controller,
                          itemCount: navState.totalPages,
                          allowImplicitScrolling: true,
                          reverse: commonSettings.readDirection == .rightToLeft,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (newPage) {
                            ref.read(nav.notifier).jumpToPage(newPage);
                          },
                          itemBuilder: (context, index) {
                            return _Page(
                              seriesId: seriesId,
                              chapterId: chapterId,
                              page: index,
                              reverse:
                                  commonSettings.readDirection == .rightToLeft,
                              outerController: controller,
                              onSelectionChanged: (selected) {
                                if (selected != hasSelection.value) {
                                  hasSelection.value = selected;
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (!navState.ready)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int page;
  final bool reverse;
  final PageController outerController;
  final void Function(bool)? onSelectionChanged;

  const _Page({
    required this.seriesId,
    required this.chapterId,
    required this.page,
    this.reverse = false,
    this.onSelectionChanged,
    required this.outerController,
  });

  bool handleScrollNotification(ScrollNotification notification) {
    if (!outerController.hasClients) return false;

    if (notification is OverscrollNotification) {
      outerController.jumpTo(
        (outerController.offset + notification.overscroll).clamp(
          0.0,
          outerController.position.maxScrollExtent,
        ),
      );
    }

    if (notification is ScrollEndNotification) {
      final rawVelocity = notification.dragDetails?.primaryVelocity ?? 0.0;

      // When reversed, physical velocity direction maps
      // to the opposite logical scroll direction.
      final dragVelocity = reverse ? -rawVelocity : rawVelocity;

      final position = outerController.position;
      final metrics = notification.metrics;

      final atBoundary =
          (dragVelocity > 0 && metrics.pixels <= metrics.minScrollExtent) ||
          (dragVelocity < 0 && metrics.pixels >= metrics.maxScrollExtent);

      if (position is ScrollPositionWithSingleContext && atBoundary) {
        position.goBallistic(-dragVelocity);
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageCache = useMemoized(() => CachedImageFactory(), []);

    final provider = epubReflowProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      page: page,
    );
    final reflow = ref.watch(provider);
    final navigationProvider = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );
    final navigation = ref.watch(navigationProvider);

    final navigationGestures = ref.watch(
      commonReaderSettingsProvider(
        seriesId: seriesId,
      ).select(
        (value) => value.whenData((data) => data.navigationGersturesEnabled),
      ),
    );

    final reduceAnimations = ref.watch(
      themeProvider.select(
        (value) =>
            value.whenOrNull(
              data: (data) => data.reduceAnimations,
            ) ??
            const ThemeModel().reduceAnimations,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVisiblePage = navigation.value?.page == page;
        final visibleReady = navigation.value?.ready ?? false;
        final shouldStart = isVisiblePage || visibleReady;

        if (shouldStart && reflow.value?.status != .done) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ref
                .read(provider.notifier)
                .startReflow(
                  viewport: constraints.biggest,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  measureBuilder: (html, styles) => EpubMeasureRoot(
                    container: ProviderScope.containerOf(context),
                    mediaQueryData: MediaQuery.of(context),
                    themeData: Theme.of(context),
                    textDirection: Directionality.of(context),
                    locale: Localizations.localeOf(context),
                    seriesId: seriesId,
                    html: html,
                    styles: styles,
                    imageCache: imageCache,
                  ),
                  refreshRate: View.of(context).display.refreshRate,
                );
          });
        }

        return Async3(
          asyncValue1: navigation,
          asyncValue2: reflow,
          asyncValue3: navigationGestures,
          data: (navigationState, reflowState, navigationGestures) {
            // include buffer spinner page if currently measuring.
            final count = reflowState.status == .measuring
                ? reflowState.subpages.length + 1
                : reflowState.subpages.length;

            return HookConsumer(
              builder: (context, ref, child) {
                final controller = usePageController(
                  initialPage: navigationState.subpage,
                );
                final scrollPhysics = navigationGestures && !reduceAnimations
                    ? const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      )
                    : const NeverScrollableScrollPhysics();

                ref.listen(
                  navigationProvider.select(
                    (state) => state.whenData(
                      (data) {
                        if (data.page != page || data.fromObserver) return null;

                        return data.subpage;
                      },
                    ),
                  ),
                  (previous, next) async {
                    next.whenData((next) async {
                      final previousSubpage = previous?.value;
                      if (next == null || next == previousSubpage) {
                        return;
                      }

                      if (controller.hasClients &&
                          controller.page?.round() != next) {
                        final isSequential =
                            previousSubpage != null &&
                            (next - previousSubpage).abs() == 1;

                        isSequential && !reduceAnimations
                            ? controller.animateToPage(
                                next,
                                duration: LayoutConstants.pageSlideDuration,
                                curve: Curves.easeInOut,
                              )
                            : controller.jumpToPage(next);
                      }
                    });
                  },
                );

                return NotificationListener<ScrollNotification>(
                  onNotification: navigationGestures
                      ? handleScrollNotification
                      : null,
                  child: PageView.builder(
                    controller: controller,
                    allowImplicitScrolling: true,
                    pageSnapping: true,
                    reverse: reverse,
                    itemCount: count,
                    physics: scrollPhysics,
                    onPageChanged: (newPage) {
                      if (navigationState.page != page) return;

                      ref
                          .read(navigationProvider.notifier)
                          .jumpToSubpage(
                            newPage,
                            fromObserver: true,
                          );
                    },
                    itemBuilder: (context, index) {
                      if (index >= reflowState.subpages.length) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return SingleChildScrollView(
                        child: SelectionArea(
                          onSelectionChanged: (selection) {
                            onSelectionChanged?.call(
                              selection != null &&
                                  selection.plainText.isNotEmpty,
                            );
                          },
                          child: RenderEpubContent(
                            seriesId: seriesId,
                            html: reflowState.subpages[index].outerHtml,
                            styles: reflowState.page.styles,
                            imageCache: imageCache,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
