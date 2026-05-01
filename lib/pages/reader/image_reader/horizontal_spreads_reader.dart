import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/image_spreads_reader.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/utils/extensions/iterable.dart';
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
    final navProvider = imageSpreadsReaderNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    ref.watch(spreadsProvider(seriesId: seriesId, chapterId: chapterId));
    ref.watch(navProvider);

    return Async(
      asyncValue: ref.watch(navProvider),
      data: (navState) => ReaderOverlay(
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
        child: Stack(
          children: [
            Offstage(
              offstage: !navState.ready,
              child: _ImageSpreadsReaderContent(
                seriesId: seriesId,
                chapterId: chapterId,
                initialSpread: navState.currentSpread,
              ),
            ),
            if (!navState.ready) ...[
              Offstage(
                child: _RenderPreviousPages(
                  seriesId: seriesId,
                  chapterId: chapterId,
                  currentSpread: navState.currentSpread,
                ),
              ),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageSpreadsReaderContent extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int initialSpread;

  const _ImageSpreadsReaderContent({
    required this.seriesId,
    required this.chapterId,
    required this.initialSpread,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController(initialPage: initialSpread);
    final ready = useState(false);
    final navProvider = imageSpreadsReaderNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final settings = ref.watch(
      imageReaderSettingsProvider(seriesId: seriesId),
    );
    final spreads = ref.watch(
      spreadsProvider(seriesId: seriesId, chapterId: chapterId),
    );

    ref.listen(navProvider, (prev, next) {
      next.whenData((next) {
        ready.value = next.ready;

        if (controller.hasClients &&
            controller.page?.round() != next.currentSpread) {
          final isSequential =
              prev != null &&
              prev.hasValue &&
              (next.currentSpread - prev.value!.currentSpread).abs() == 1;

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

    return Async(
      asyncValue: settings,
      data: (settings) {
        return Async(
          asyncValue: spreads,
          data: (spreads) {
            return PageView.builder(
              controller: controller,
              allowImplicitScrolling: true,
              scrollDirection: Axis.horizontal,
              reverse: settings.readDirection == .rightToLeft,
              itemCount: spreads.spreads.length,
              pageSnapping: true,
              onPageChanged: (spreadIndex) {
                ref.read(navProvider.notifier).jumpToSpread(spreadIndex);
              },
              itemBuilder: (context, spreadIndex) {
                final spread = spreads.spreads[spreadIndex];

                return Row(
                  textDirection: settings.readDirection == .rightToLeft
                      ? .rtl
                      : .ltr,
                  children: spread
                      .map<Widget>((page) {
                        Alignment alignment;

                        if (spread.length == 1) {
                          alignment = .center;
                        } else if (settings.readDirection == .rightToLeft) {
                          alignment = page == spread.first
                              ? .centerLeft
                              : .centerRight;
                        } else {
                          alignment = page == spread.first
                              ? .centerRight
                              : .centerLeft;
                        }

                        final width =
                            (MediaQuery.of(context).size.width *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt();

                        final imageCacheWidth = spread.length == 1
                            ? width
                            : width ~/ 2;

                        return Expanded(
                          child: _RenderPage(
                            chapterId: chapterId,
                            seriesId: seriesId,
                            page: page,
                            alignment: alignment,
                            imageCacheWidth: imageCacheWidth,
                          ),
                        );
                      })
                      .interleave(
                        SizedBox.square(
                          dimension: settings.spreadReaderGap,
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RenderPreviousPages extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int currentSpread;

  const _RenderPreviousPages({
    required this.seriesId,
    required this.chapterId,
    required this.currentSpread,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(
        spreadsProvider(seriesId: seriesId, chapterId: chapterId),
      ),
      data: (spreads) {
        final pagesToRender = spreads.spreads
            .take(currentSpread)
            .expand((spread) => spread)
            .toList();

        final cacheWidth =
            (MediaQuery.of(context).size.width *
                MediaQuery.of(context).devicePixelRatio) ~/
            2;

        return Stack(
          children: pagesToRender.map((page) {
            return _RenderPage(
              seriesId: seriesId,
              chapterId: chapterId,
              page: page,
              alignment: .center,
              imageCacheWidth: cacheWidth,
            );
          }).toList(),
        );
      },
    );
  }
}

class _RenderPage extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int page;
  final Alignment alignment;
  final int? imageCacheWidth;

  const _RenderPage({
    required this.seriesId,
    required this.chapterId,
    required this.page,
    this.imageCacheWidth,
    this.alignment = .center,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(
        imagePageProvider(
          chapterId: chapterId,
          page: page,
        ),
      ),
      data: (data) {
        return _OrientationDetector(
          alignment: alignment,
          image: Image.memory(
            data.data,
            fit: .contain,
            alignment: alignment,
            cacheWidth: imageCacheWidth,
          ),
          onRendered: (size) async {
            await ref
                .read(
                  spreadsProvider(
                    seriesId: seriesId,
                    chapterId: chapterId,
                  ).notifier,
                )
                .markRendered(page);
            if (size.width > size.height) {
              await ref
                  .read(
                    spreadsProvider(
                      seriesId: seriesId,
                      chapterId: chapterId,
                    ).notifier,
                  )
                  .markLandscape(page);
            }
          },
        );
      },
    );
  }
}

class _OrientationDetector extends HookWidget {
  final Image image;
  final void Function(Size size) onRendered;
  final Alignment alignment;

  const _OrientationDetector({
    required this.image,
    required this.onRendered,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      final stream = image.image.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((ImageInfo info, bool sync) {
        onRendered(
          Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
        );
      });

      stream.addListener(listener);

      return () => stream.removeListener(listener);
    }, [image]);

    return image;
  }
}
