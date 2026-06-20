import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:html/dom.dart';
import 'package:kover/pages/reader/epub_reader/epub_toc_drawer.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/cached_image_factory.dart';
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
    final nav = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final commonSettings = ref.watch(
      commonReaderSettingsProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: commonSettings,
      data: (commonSettings) => ReaderOverlay(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
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

                    isSequential
                        ? controller.animateToPage(
                            nextPage,
                            duration: 200.ms,
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
                          );
                        },
                      ),
                    ),
                  ),
                  if (!navState.ready)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            },
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

  const _Page({
    required this.seriesId,
    required this.chapterId,
    required this.page,
    this.reverse = false,
    required this.outerController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reflow = ref.watch(
      epubReflowProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: page,
      ),
    );
    final nav = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: _MeasureContent(
            seriesId: seriesId,
            chapterId: chapterId,
            page: page,
          ),
        ),
        Positioned.fill(
          child: Async2(
            asyncValue1: ref.watch(nav),
            asyncValue2: reflow,
            data: (navState, reflowState) {
              // include buffer spinner page if currently measuring.
              final count = reflowState.status == .measuring
                  ? reflowState.subpages.length + 1
                  : reflowState.subpages.length;

              return HookConsumer(
                builder: (context, ref, child) {
                  final controller = usePageController(
                    initialPage: navState.subpage,
                  );

                  ref.listen(nav, (
                    previous,
                    next,
                  ) async {
                    next.whenData((next) async {
                      final previousSubpage = previous?.value?.subpage;
                      final nextSubpage = next.subpage;

                      if (next.page != page ||
                          next.fromObserver ||
                          nextSubpage == previousSubpage) {
                        return;
                      }

                      if (controller.hasClients &&
                          controller.page?.round() != nextSubpage) {
                        final isSequential =
                            previousSubpage != null &&
                            (nextSubpage - previousSubpage).abs() == 1;

                        isSequential
                            ? controller.animateToPage(
                                nextSubpage,
                                duration: 200.ms,
                                curve: Curves.easeInOut,
                              )
                            : controller.jumpToPage(nextSubpage);
                      }
                    });
                  });

                  return Stack(
                    children: [
                      Offstage(
                        offstage: navState.page > page,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (!outerController.hasClients) return false;

                            if (notification is OverscrollNotification) {
                              outerController.jumpTo(
                                (outerController.offset +
                                        notification.overscroll)
                                    .clamp(
                                      0.0,
                                      outerController.position.maxScrollExtent,
                                    ),
                              );
                            }

                            if (notification is ScrollEndNotification) {
                              final rawVelocity =
                                  notification.dragDetails?.primaryVelocity ??
                                  0.0;

                              // When reversed, physical velocity direction maps
                              // to the opposite logical scroll direction.
                              final dragVelocity = reverse
                                  ? -rawVelocity
                                  : rawVelocity;

                              final position = outerController.position;
                              final metrics = notification.metrics;

                              final atBoundary =
                                  (dragVelocity > 0 &&
                                      metrics.pixels <=
                                          metrics.minScrollExtent) ||
                                  (dragVelocity < 0 &&
                                      metrics.pixels >=
                                          metrics.maxScrollExtent);

                              if (position is ScrollPositionWithSingleContext &&
                                  atBoundary) {
                                position.goBallistic(-dragVelocity);
                              }
                            }

                            return false;
                          },
                          child: PageView.builder(
                            controller: controller,
                            allowImplicitScrolling: true,
                            pageSnapping: true,
                            reverse: reverse,
                            itemCount: count,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            onPageChanged: (newPage) {
                              if (navState.page != page) return;

                              ref
                                  .read(nav.notifier)
                                  .jumpToSubpage(newPage, fromObserver: true);
                            },
                            itemBuilder: (context, index) {
                              if (index >= reflowState.subpages.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return SingleChildScrollView(
                                child: _RenderContent(
                                  seriesId: seriesId,
                                  html: reflowState.subpages[index].outerHtml,
                                  styles: reflowState.page.styles,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (navState.page > page)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MeasureContent extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int page;
  const _MeasureContent({
    required this.seriesId,
    required this.chapterId,
    required this.page,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = useState(GlobalKey());
    final provider = epubReflowProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      page: page,
    );
    final reflow = ref.watch(provider);
    final imageCache = useState(CachedImageFactory());

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await WidgetsBinding.instance.endOfFrame;
          final renderBox =
              key.value.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) {
            return;
          }

          if (!renderBox.hasSize ||
              renderBox.size.height <= constraints.maxHeight) {
            await ref.read(provider.notifier).addElement();
          } else {
            await ref.read(provider.notifier).overflow();
          }
        });

        return Async(
          asyncValue: reflow,
          data: (data) => Offstage(
            child: Column(
              mainAxisSize: .min,
              children: [
                _RenderContent(
                  seriesId: seriesId,
                  key: key.value,
                  styles: data.page.styles,
                  html: (data.buffer ?? DocumentFragment()).outerHtml,
                  imageCache: imageCache.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RenderContent extends ConsumerWidget {
  final int seriesId;
  final String html;
  final Map<String, Map<String, String>> styles;
  final CachedImageFactory? imageCache;

  const _RenderContent({
    super.key,
    required this.seriesId,
    required this.html,
    required this.styles,
    this.imageCache,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epubSettings = ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: epubSettings,
      data: (epubSettings) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(epubSettings.marginSize),
          child: HtmlWidget(
            html,
            buildAsync: false,
            enableCaching: true,
            factoryBuilder: () => imageCache ?? CachedImageFactory(),
            customStylesBuilder: (element) {
              final s = Map<String, String>.from(
                styles[element.localName] ?? {},
              );

              for (final className in element.classes) {
                s.addAll(styles['.$className'] ?? {});
              }

              return s;
            },
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: epubSettings.fontSize,
              height: epubSettings.lineHeight,
              wordSpacing: epubSettings.wordSpacing,
              letterSpacing: epubSettings.letterSpacing,
            ),
          ),
        ),
      ),
    );
  }
}
