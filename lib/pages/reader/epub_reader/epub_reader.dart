import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/epub_horizontal_subpages.dart';
import 'package:kover/pages/reader/epub_reader/epub_measure_root.dart';
import 'package:kover/pages/reader/epub_reader/epub_toc_drawer.dart';
import 'package:kover/pages/reader/epub_reader/epub_theme_override.dart';
import 'package:kover/pages/reader/epub_reader/epub_vertical_subpages.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
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

    final readerMode = ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId).select(
        (state) => state.whenData((data) => data.mode),
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

    return Async2(
      asyncValue1: commonSettings,
      asyncValue2: readerMode,
      data: (commonSettings, readerMode) => ReaderOverlay(
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

                return SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Offstage(
                          offstage: !navState.ready,
                          child: PageView.builder(
                            clipBehavior: .none,
                            controller: controller,
                            itemCount: navState.totalPages,
                            allowImplicitScrolling: true,
                            scrollCacheExtent: const .viewport(4),
                            scrollDirection: switch (readerMode) {
                              .horizontal => .horizontal,
                              .vertical => .vertical,
                              .spreads => .horizontal,
                            },
                            reverse:
                                commonSettings.readDirection == .rightToLeft &&
                                readerMode != .vertical,
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
                                    commonSettings.readDirection ==
                                        .rightToLeft &&
                                    readerMode != .vertical,
                                mode: readerMode,
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
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
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
  final EpubReaderMode mode;
  final PageController outerController;
  final void Function(bool)? onSelectionChanged;

  const _Page({
    required this.seriesId,
    required this.chapterId,
    required this.page,
    required this.mode,
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
    final container = ProviderScope.containerOf(context);
    final mediaQueryData = MediaQuery.of(context);
    final themeData = Theme.of(context);
    final textDirection = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    final imageCache = useMemoized(
      () => CachedImageFactory(maxHeight: mediaQueryData.size.height),
      [],
    );
    final vertical = mode == .vertical;
    final spreads = mode == .spreads;

    final provider = epubReflowProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      page: page,
    );

    final subpageState = ref.watch(
      epubReaderSubpageProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: page,
      ),
    );

    return Async(
      asyncValue: subpageState,
      skipLoadingOnReload: true,
      data: (data) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isVisiblePage = data.navigation.page == page;
            final visibleReady = data.navigation.ready;
            final shouldStart = isVisiblePage || visibleReady;

            if (shouldStart && data.reflow.status != .done) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ref
                    .read(provider.notifier)
                    .startReflow(
                      viewport: spreads
                          ? Size(
                              constraints.maxWidth / 2,
                              constraints.maxHeight,
                            )
                          : constraints.biggest,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      measureBuilder: (html, styles) => EpubMeasureRoot(
                        container: container,
                        mediaQueryData: mediaQueryData,
                        themeData: themeData,
                        textDirection: textDirection,
                        locale: locale,
                        seriesId: seriesId,
                        html: html,
                        styles: styles,
                        imageCache: imageCache,
                        verticalPadding: !vertical,
                      ),
                      refreshRate: View.of(context).display.refreshRate,
                    );
              });
            }

            return SelectionArea(
              onSelectionChanged: (selection) {
                onSelectionChanged?.call(
                  selection != null && selection.plainText.isNotEmpty,
                );
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: data.navigationGesturesEnabled
                    ? handleScrollNotification
                    : null,
                child: vertical
                    ? EpubVerticalSubpages(
                        key: ValueKey(page),
                        seriesId: seriesId,
                        chapterId: chapterId,
                        page: page,
                        imageCache: imageCache,
                      )
                    : EpubHorizontalSubpages(
                        key: ValueKey(page),
                        seriesId: seriesId,
                        chapterId: chapterId,
                        page: page,
                        imageCache: imageCache,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
