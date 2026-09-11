import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/mapping/enums/read_direction.dart';
import 'package:kover/pages/reader/image_reader/horizontal_paged_reader_provider.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class HorizontalPagedReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;

  const HorizontalPagedReader({
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

    final model = ref.watch(
      horizontalPagedReaderProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );

    return Async(
      asyncValue: model,
      data: (data) {
        return HookConsumer(
          builder: (context, ref, _) {
            final pageController = usePageController(
              initialPage: data.navState.currentPage,
            );
            final zoomedPageIndexes = useState(<int>{});
            // Number of touch pointers down. With 2+ fingers we hand the
            // gesture to the InteractiveViewer (pinch-zoom) instead of letting
            // the PageView's drag recognizer steal it as a page swipe.
            final pointerCount = useState(0);

            ref.listen(
              navProvider.select((s) => s.whenData((s) => s.currentPage)),
              (
                previous,
                next,
              ) {
                next.whenData((next) {
                  if (pageController.hasClients &&
                      pageController.page?.round() != next) {
                    final isSequential =
                        previous != null &&
                        previous.value != null &&
                        (next - previous.value!).abs() == 1;

                    isSequential && !data.reduceAnimations
                        ? pageController.animateToPage(
                            next,
                            duration: LayoutConstants.pageSlideDuration,
                            curve: Curves.easeInOut,
                          )
                        : pageController.jumpToPage(next);
                  }
                });
              },
            );
            final enabledScrollPhysics =
                zoomedPageIndexes.value.contains(data.navState.currentPage) ||
                    pointerCount.value >= 2
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics();

            final scrollPhysics =
                data.commonSettings.navigationGersturesEnabled &&
                    !data.reduceAnimations
                ? enabledScrollPhysics
                : const NeverScrollableScrollPhysics();

            final content = Directionality(
              textDirection: data.commonSettings.readDirection
                  .toTextDirection(),
              child: PageView.builder(
                controller: pageController,
                allowImplicitScrolling: true,
                scrollDirection: .horizontal,
                itemCount: data.reader.totalPages,
                pageSnapping: true,
                physics: scrollPhysics,
                onPageChanged: (index) {
                  ref.read(navProvider.notifier).jumpToPage(index);
                },
                itemBuilder: (context, index) {
                  return Async(
                    asyncValue: ref.watch(
                      imagePageProvider(
                        chapterId: chapterId,
                        page: index,
                      ),
                    ),
                    data: (page) {
                      return ZoomableHorizontalPageImage(
                        key: ValueKey(index),
                        outerController: pageController,
                        onZoomChanged: (zoomed) {
                          if (zoomedPageIndexes.value.contains(index) ==
                              zoomed) {
                            return;
                          }

                          final nextZoomedPageIndexes = {
                            ...zoomedPageIndexes.value,
                          };

                          zoomed
                              ? nextZoomedPageIndexes.add(index)
                              : nextZoomedPageIndexes.remove(index);
                          zoomedPageIndexes.value = nextZoomedPageIndexes;
                        },
                        child: Image.memory(
                          page.data,
                          fit: switch (data.settings.scaleType) {
                            .contain => .contain,
                            .fitWidth => .fitWidth,
                            .fitHeight => .fitHeight,
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            );

            final listenedContent = Listener(
              onPointerDown: (_) => pointerCount.value++,
              onPointerUp: (_) =>
                  pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
              onPointerCancel: (_) =>
                  pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
              child: content,
            );

            if (data.settings.ignoreSafeAreas) {
              return listenedContent;
            }

            return SafeArea(child: listenedContent);
          },
        );
      },
    );
  }
}
