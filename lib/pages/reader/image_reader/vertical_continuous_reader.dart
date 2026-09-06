import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';
import 'package:kover/pages/reader/image_reader/zoomable_vertical_scroll_view.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/image_vertical_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/utils/hooks/use_sliver_observer_controller.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class VerticalContinuousReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;

  const VerticalContinuousReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final nav = ref.watch(navProvider);

    final settings = ref.watch(
      imageReaderSettingsProvider(seriesId: seriesId),
    );

    ref.listen(
      imageReaderSettingsProvider(seriesId: seriesId).select(
        (settings) => settings.value?.verticalReaderPadding,
      ),
      (previous, next) {
        if (previous != next) {
          ref
              .read(
                verticalReaderCacheProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                ).notifier,
              )
              .clearCache();
        }
      },
    );

    return Async2(
      asyncValue1: nav,
      asyncValue2: settings,
      data: (nav, settings) {
        return HookConsumer(
          builder: (context, ref, _) {
            final scrollController = useScrollController();
            final gestureController = useMemoized(
              VerticalReaderGestureController.new,
            );
            final observerController = useSliverObserverController(
              controller: scrollController,
              initialIndex: nav.currentPage,
            );

            useEffect(() => gestureController.dispose, [gestureController]);

            /// Emit last-page progress when scrolled to bottom edge.
            void handleScrollEnd() {
              final pos = scrollController.position;
              if (pos.atEdge && pos.pixels >= pos.maxScrollExtent) {
                final lastIndex = nav.totalPages - 1;
                final navProvider = readerNavigationProvider(
                  seriesId: seriesId,
                  chapterId: chapterId,
                );
                ref.read(navProvider).whenData((navState) {
                  ref
                      .read(navProvider.notifier)
                      .jumpToPage(lastIndex, fromObserver: true);
                });
              }
            }

            scrollController.addListener(handleScrollEnd);

            ref.listen(
              navProvider,
              (previous, next) {
                next.whenData((next) async {
                  if (!scrollController.hasClients ||
                      previous?.value?.currentPage == next.currentPage) {
                    return;
                  }

                  if (next.fromObserver) {
                    return;
                  }

                  final isSequential =
                      previous != null &&
                      previous.hasValue &&
                      (next.currentPage - previous.value!.currentPage).abs() ==
                          1;

                  if (isSequential) {
                    await observerController.animateTo(
                      index: next.currentPage,
                      duration: LayoutConstants.pageSlideDuration,
                      curve: Curves.easeInOut,
                    );
                  } else {
                    await observerController.jumpTo(index: next.currentPage);
                  }
                });
              },
            );

            final content = ZoomableVerticalScrollView(
              scrollController: scrollController,
              gestureController: gestureController,
              lockHorizontalPan: settings.lockHorizontalPan,
              child: SliverViewObserver(
                controller: observerController,
                onObserve: (ObserveModel model) {
                  if (model is! ListViewObserveModel) return;

                  final firstVisibleIndex = model.firstChild?.index;
                  if (firstVisibleIndex == null) return;

                  if (model.displayingChildIndexList.contains(
                    nav.totalPages - 1,
                  )) {
                    ref
                        .read(navProvider.notifier)
                        .jumpToPage(nav.totalPages - 1, fromObserver: true);
                    return;
                  }

                  ref
                      .read(navProvider.notifier)
                      .jumpToPage(firstVisibleIndex, fromObserver: true);
                },
                child: CustomScrollView(
                  controller: scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.viewport(5),
                  scrollBehavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: false,
                  ),
                  slivers: [
                    AnimatedBuilder(
                      animation: gestureController,
                      builder: (context, _) {
                        return SliverSafeArea(
                          sliver: SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: settings.verticalReaderPadding,
                              vertical: gestureController.verticalScrollPadding,
                            ),
                            sliver: SliverList.separated(
                              itemCount: nav.totalPages,
                              itemBuilder: (context, index) =>
                                  _VerticalReaderItem(
                                    chapterId: chapterId,
                                    seriesId: seriesId,
                                    page: index,
                                  ),
                              separatorBuilder: (context, index) => SizedBox(
                                height: settings.verticalReaderGap,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  ref
                      .read(
                        verticalReaderCacheProvider(
                          seriesId: seriesId,
                          chapterId: chapterId,
                        ).notifier,
                      )
                      .measurePreviousPages(
                        currentPage: nav.currentPage,
                        viewport: constraints.biggest,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                        horizontalPadding: settings.verticalReaderPadding,
                        refreshRate: View.of(context).display.refreshRate,
                      );
                });

                if (settings.ignoreSafeAreas) {
                  return content;
                }

                return SafeArea(child: content);
              },
            );
          },
        );
      },
    );
  }
}

class _VerticalReaderItem extends ConsumerWidget {
  final int chapterId;
  final int seriesId;
  final int page;

  const _VerticalReaderItem({
    required this.chapterId,
    required this.seriesId,
    required this.page,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(
      imagePageProvider(chapterId: chapterId, page: page),
    );

    final cachedHeight = ref.watch(
      verticalReaderCacheProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).select(
        (state) => state.whenOrNull(data: (state) => state.cachedHeights[page]),
      ),
    );

    return Async(
      asyncValue: image,
      data: (image) {
        return SizedBox(
          height: cachedHeight,
          child: _RenderImage(image: image),
        );
      },
      loading: () => SizedBox(
        height: cachedHeight,
        child: const AspectRatio(
          aspectRatio: 5 / 8,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _RenderImage extends StatelessWidget {
  final ImageModel image;
  const _RenderImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final cacheWidth =
        (MediaQuery.of(context).size.width *
                MediaQuery.of(context).devicePixelRatio)
            .ceil();

    return Image.memory(
      image.data,
      fit: BoxFit.fitWidth,
      cacheWidth: cacheWidth,
    );
  }
}
