import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/reader_overlay.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/image_spreads_reader.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/widgets/async_value.dart';

class HorizontalSpreadsReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;

  const HorizontalSpreadsReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));

    final navProvider = imageSpreadsReaderNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    return ReaderOverlay(
      chapterId: chapterId,
      seriesId: seriesId,
      onNextPage: () {
        ref.read(navProvider.notifier).nextPage();
      },
      onPreviousPage: () {
        ref.read(navProvider.notifier).previousPage();
      },
      onJumpToPage: (page) {
        ref.read(navProvider.notifier).jumpToPage(page);
      },
      isLastPage: (page) =>
          ref
              .read(spreadsProvider(seriesId: seriesId, chapterId: chapterId))
              .value
              ?.spreads
              .last
              .contains(page) ??
          false,
      child: Async(
        asyncValue: ref.watch(navProvider),
        data: (navState) {
          return Async(
            asyncValue: ref.watch(
              spreadsProvider(seriesId: seriesId, chapterId: chapterId),
            ),
            data: (spreads) {
              return Async(
                asyncValue: settings,
                data: (settings) {
                  return HookConsumer(
                    builder: (context, ref, _) {
                      final controller = usePageController(
                        initialPage: navState.currentSpread,
                      );
                      ref.listen(navProvider, (prev, next) {
                        next.whenData((next) {
                          if (controller.hasClients &&
                              controller.page?.round() != next.currentSpread) {
                            final isSequential =
                                prev != null &&
                                prev.hasValue &&
                                (next.currentSpread - prev.value!.currentSpread)
                                        .abs() ==
                                    1;

                            isSequential
                                ? controller.animateToPage(
                                    next.currentSpread,
                                    duration: 200.ms,
                                    curve: Curves.easeInOut,
                                  )
                                : controller.jumpToPage(next.currentSpread);
                          }
                        });
                      });
                      return PageView.builder(
                        controller: controller,
                        allowImplicitScrolling: true,
                        scrollDirection: Axis.horizontal,
                        reverse: settings.readDirection == .rightToLeft,
                        itemCount: spreads.spreads.length,
                        pageSnapping: true,
                        onPageChanged: (spreadIndex) {
                          ref
                              .read(navProvider.notifier)
                              .jumpToSpread(spreadIndex);
                        },
                        itemBuilder: (context, spreadIndex) {
                          final spread = spreads.spreads[spreadIndex];

                          return Row(
                            textDirection:
                                settings.readDirection == .rightToLeft
                                ? .rtl
                                : .ltr,
                            children: spread.map((page) {
                              Alignment alignment;

                              if (spread.length == 1) {
                                alignment = .center;
                              } else if (settings.readDirection ==
                                  .rightToLeft) {
                                alignment = page == spread.first
                                    ? .centerLeft
                                    : .centerRight;
                              } else {
                                alignment = page == spread.first
                                    ? .centerRight
                                    : .centerLeft;
                              }

                              return Expanded(
                                child: Async(
                                  asyncValue: ref.watch(
                                    imagePageProvider(
                                      chapterId: chapterId,
                                      page: page,
                                    ),
                                  ),
                                  data: (data) {
                                    return Image.memory(
                                      data.data,
                                      fit: .contain,
                                      alignment: alignment,
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
