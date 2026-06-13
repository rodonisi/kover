import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
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
    final reader = ref.watch(provider);

    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final navState = ref.watch(navProvider);

    return Async3(
      asyncValue1: reader,
      asyncValue2: settings,
      asyncValue3: navState,
      data: (reader, settings, navState) {
        return HookConsumer(
          builder: (context, ref, _) {
            final pageController = usePageController(
              initialPage: navState.currentPage,
            );
            final isZoomed = useState(false);
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

                    isSequential
                        ? pageController.animateToPage(
                            next,
                            duration: 200.ms,
                            curve: Curves.easeInOut,
                          )
                        : pageController.jumpToPage(next);
                  }
                });
              },
            );

            final content = PageView.builder(
              controller: pageController,
              allowImplicitScrolling: true,
              scrollDirection: .horizontal,
              reverse: settings.readDirection == .rightToLeft,
              itemCount: reader.totalPages,
              pageSnapping: true,
              physics: isZoomed.value || pointerCount.value >= 2
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                isZoomed.value = false; // new page starts unzoomed (ValueKey)
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
                      onZoomChanged: (zoomed) => isZoomed.value = zoomed,
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
