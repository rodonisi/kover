import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';

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
    final provider = readerProvider(seriesId: seriesId, chapterId: chapterId);

    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));
    final commonSettings = ref.watch(
      commonReaderSettingsProvider(seriesId: seriesId),
    );
    final reader = ref.watch(provider);

    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final navState = ref.watch(navProvider);

    final reduceAnimations = ref.watch(
      themeProvider.select(
        (value) =>
            value.whenOrNull(
              data: (data) => data.reduceAnimations,
            ) ??
            const ThemeModel().reduceAnimations,
      ),
    );

    return Async4(
      asyncValue1: reader,
      asyncValue2: navState,
      asyncValue3: settings,
      asyncValue4: commonSettings,
      data: (reader, navState, settings, commonSettings) {
        return HookConsumer(
          builder: (context, ref, _) {
            final pageController = usePageController(
              initialPage: navState.currentPage,
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

                    isSequential && !reduceAnimations
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
                zoomedPageIndexes.value.contains(navState.currentPage) ||
                    pointerCount.value >= 2
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics();

            final scrollPhysics =
                commonSettings.navigationGersturesEnabled && !reduceAnimations
                ? enabledScrollPhysics
                : const NeverScrollableScrollPhysics();

            final content = PageView.builder(
              controller: pageController,
              allowImplicitScrolling: true,
              scrollDirection: .horizontal,
              reverse: commonSettings.readDirection == .rightToLeft,
              itemCount: reader.totalPages,
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
                  data: (data) {
                    return ZoomableHorizontalPageImage(
                      key: ValueKey(index),
                      outerController: pageController,
                      onZoomChanged: (zoomed) {
                        final nextZoomedPageIndexes = {
                          ...zoomedPageIndexes.value,
                        };
                        zoomed
                            ? nextZoomedPageIndexes.add(index)
                            : nextZoomedPageIndexes.remove(index);
                        zoomedPageIndexes.value = nextZoomedPageIndexes;
                      },
                      child: Image.memory(
                        data.data,
                        fit: switch (settings.scaleType) {
                          .contain => .contain,
                          .fitWidth => .fitWidth,
                          .fitHeight => .fitHeight,
                        },
                      ),
                    );
                  },
                );
              },
            );

            final listenedContent = Listener(
              onPointerDown: (_) => pointerCount.value++,
              onPointerUp: (_) =>
                  pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
              onPointerCancel: (_) =>
                  pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
              child: content,
            );

            if (settings.ignoreSafeAreas) {
              return listenedContent;
            }

            return SafeArea(child: listenedContent);
          },
        );
      },
    );
  }
}
