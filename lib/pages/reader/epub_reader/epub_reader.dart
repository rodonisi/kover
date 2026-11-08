import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/mapping/enums/read_direction.dart';
import 'package:kover/pages/reader/epub_reader/epub_reader_provider.dart';
import 'package:kover/pages/reader/epub_reader/epub_theme_override.dart';
import 'package:kover/pages/reader/epub_reader/epub_toc_drawer.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page_provider.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class EpubReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int? readingListId;

  const EpubReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
    required this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = useState(false);
    final nav = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );

    final model = ref.watch(
      epubReaderProvider(seriesId: seriesId),
    );
    final ignoreSafeAreas = ref.watch(
      epubReaderSettingsProvider(
        seriesId: seriesId,
      ).select((state) => state.value?.ignoreSafeAreas ?? true),
    );

    return Async(
      asyncValue: model,
      data: (data) => ReaderOverlay(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
        disableGestures: hasSelection.value,
        onNextPage: () {
          ref.read(nav.notifier).nextPage();
        },
        onPreviousPage: () {
          ref.read(nav.notifier).previousPage();
        },
        onJumpToPage: (page) {
          ref.read(nav.notifier).jumpToPage(page);
        },
        endDrawer: EpubTocDrawer(
          seriesId: seriesId,
          chapterId: chapterId,
          readingListId: readingListId,
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

                    hasSelection.value = false;

                    if (controller.hasClients &&
                        controller.page?.round() != nextPage) {
                      final isSequential =
                          previousPage != null &&
                          (nextPage - previousPage).abs() == 1;

                      isSequential && !data.reduceAnimations
                          ? controller.animateToPage(
                              nextPage,
                              duration: LayoutConstants.pageSlideDuration,
                              curve: Curves.easeInOut,
                            )
                          : controller.jumpToPage(nextPage);
                    }
                  });
                });

                final respectSafeAreas =
                    data.mode != .vertical || !ignoreSafeAreas;

                return Directionality(
                  textDirection: data.commonSettings.readDirection
                      .toTextDirection(),
                  child: SafeArea(
                    left: respectSafeAreas,
                    top: respectSafeAreas,
                    right: respectSafeAreas,
                    bottom: respectSafeAreas,
                    child: PageView.builder(
                      clipBehavior: respectSafeAreas ? .hardEdge : .none,
                      controller: controller,
                      itemCount: navState.totalPages,
                      allowImplicitScrolling: true,
                      scrollDirection: switch (data.mode) {
                        .horizontal => .horizontal,
                        .vertical => .vertical,
                        .spreads => .horizontal,
                      },
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (newPage) {
                        ref.read(nav.notifier).jumpToPage(newPage, force: true);
                      },
                      itemBuilder: (context, index) {
                        return _Page(
                          seriesId: seriesId,
                          chapterId: chapterId,
                          readingListId: readingListId,
                          page: index,
                          reverse:
                              data.commonSettings.readDirection ==
                                  .rightToLeft &&
                              data.mode != .vertical,
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
  final int? readingListId;
  final int page;
  final bool reverse;
  final PageController outerController;
  final void Function(bool)? onSelectionChanged;

  const new({
    required this.seriesId,
    required this.chapterId,
    required this.readingListId,
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
    final nav = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );
    final model = ref.watch(
      paginatedEpubPageProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
        page: page,
      ),
    );
    final controller = useMemoized(
      () => PaginatedEpubPageController(
        onSubpageChanged: (subpage, scrollId) {
          onSelectionChanged?.call(false);
          ref
              .read(nav.notifier)
              .jumpToSubpage(subpage, scrollId: scrollId, page: page);
        },
        onSubpagesCountChanged: (count) {
          ref.read(nav.notifier).updateSubpageCount(page, count);
        },
      ),
    );
    useEffect(() => controller.dispose, [controller]);

    final navState = ref.read(nav).value;
    if (navState != null &&
        navState.page == page &&
        controller.status == .measuring) {
      controller.setPendingSubpage(navState.subpage);
    }

    ref.listen(
      nav,
      (previous, next) {
        next.whenData((next) {
          if (next.page != page) {
            controller.setPendingSubpage(null);
            return;
          }

          if (controller.status == .ready) {
            ref
                .read(nav.notifier)
                .updateSubpageCount(page, controller.subpageCount);
            if (controller.currentSubpage != next.subpage) {
              controller.jumpToSubpage(next.subpage);
            }
          } else {
            controller.setPendingSubpage(next.subpage);
          }
        });
      },
    );

    return Async(
      asyncValue: model,
      data: (data) => NotificationListener<ScrollNotification>(
        onNotification: data.settings.canScroll
            ? handleScrollNotification
            : null,
        child: PaginatedEpubPage(
          controller: controller,
          html: data.html,
          settings: data.settings,
          resumeScrollId: data.resumeScrollId,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    );
  }
}
