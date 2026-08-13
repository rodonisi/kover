import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/utils/hooks/use_sliver_observer_controller.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class const EpubVerticalSubpages({
  super.key,
  required final int seriesId,
  required final int chapterId,
  required final int page,
  required final CachedImageFactory imageCache,
}) extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationProvider = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );
    final subpageState = ref.watch(
      epubReaderSubpageProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: page,
      ),
    );
    final data = subpageState.requireValue;

    // include buffer spinner page if currently measuring.
    final count = data.reflow.status == .measuring
        ? data.reflow.subpages.length + 1
        : data.reflow.subpages.length;

    final scrollController = useScrollController();
    final observerController = useSliverObserverController(
      controller: scrollController,
      initialIndex: data.navigation.subpage,
    );

    ref.listen(
      navigationProvider.select(
        (state) => state.whenData(
          (data) {
            if (data.page != page || data.fromObserver) return null;

            return data.subpage;
          },
        ),
      ),
      (previous, next) async {
        next.whenData((next) async {
          final previousSubpage = previous?.value;
          if (next == null ||
              next == previousSubpage ||
              !scrollController.hasClients ||
              count == 0) {
            return;
          }

          final target = next.clamp(0, count - 1);

          final isSequential =
              previousSubpage != null && (target - previousSubpage).abs() == 1;

          isSequential && !data.reduceAnimations
              ? await observerController.animateTo(
                  index: target,
                  duration: LayoutConstants.pageSlideDuration,
                  curve: Curves.easeInOut,
                )
              : await observerController.jumpTo(index: target);
        });
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SliverViewObserver(
          controller: observerController,
          onObserve: (ObserveModel model) {
            if (model is! ListViewObserveModel ||
                data.navigation.page != page ||
                data.reflow.status == .measuring) {
              return;
            }

            final firstVisibleIndex = model.firstChild?.index;
            if (firstVisibleIndex == null) return;

            final lastSubpage = data.reflow.subpages.length - 1;

            // report last subpage on bottom edge
            if (model.displayingChildIndexList.contains(lastSubpage)) {
              ref
                  .read(navigationProvider.notifier)
                  .jumpToSubpage(lastSubpage, fromObserver: true);
              return;
            }

            ref
                .read(navigationProvider.notifier)
                .jumpToSubpage(
                  firstVisibleIndex.clamp(0, lastSubpage),
                  fromObserver: true,
                );
          },
          child: CustomScrollView(
            controller: scrollController,
            clipBehavior: .none,
            scrollCacheExtent: const .viewport(4),
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverList.builder(
                itemCount: count,
                itemBuilder: (context, index) {
                  final Widget content =
                      data.reflow.status == .measuring &&
                          index >= data.reflow.subpages.length
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : RenderEpubContent(
                          seriesId: seriesId,
                          html: data.reflow.subpages[index].outerHtml,
                          styles: data.reflow.page.styles,
                          imageCache: imageCache,
                          verticalPadding: false,
                        );

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight * 0.9 - data.paragraphSpacing,
                    ),
                    child: content,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
