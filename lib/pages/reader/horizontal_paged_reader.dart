import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/widgets/async_value.dart';

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
    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));
    final provider = readerProvider(seriesId: seriesId, chapterId: chapterId);

    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final navState = ref.watch(navProvider);

    final pageController = usePageController(initialPage: navState.currentPage);

    ref.listen(navProvider.select((s) => s.currentPage), (previous, next) {
      if (pageController.hasClients && pageController.page?.round() != next) {
        final isSequential = previous != null && (next - previous).abs() == 1;

        isSequential
            ? pageController.animateToPage(
                next,
                duration: 200.ms,
                curve: Curves.easeInOut,
              )
            : pageController.jumpToPage(next);
      }
    });
    return Async(
      asyncValue: ref.watch(provider),
      data: (state) {
        return Async(
          asyncValue: settings,
          data: (settings) => PageView.builder(
            controller: pageController,
            allowImplicitScrolling: true,
            scrollDirection: .horizontal,
            reverse: settings.readDirection == .rightToLeft,
            itemCount: state.totalPages,
            pageSnapping: true,
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
                  return Image.memory(
                    data.data,
                    fit: settings.scaleType == .fitWidth
                        ? .fitWidth
                        : .fitHeight,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
