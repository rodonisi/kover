import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class const EpubHorizontalSubpages({
  super.key,
  required final int seriesId,
  required final int chapterId,
  required final int page,
  required final CachedImageFactory imageCache,
}) extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subpageState = ref.watch(
      epubReaderSubpageProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        page: page,
      ),
    );

    final navigationProvider = epubNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );
    final data = subpageState.requireValue;

    final spreads = data.mode == .spreads;
    final controller = usePageController(
      initialPage: spreads
          ? data.navigation.subpage ~/ 2
          : data.navigation.subpage,
    );

    // include buffer spinner page if currently measuring.
    final count = data.reflow.status == .measuring
        ? data.reflow.subpages.length + 1
        : data.reflow.subpages.length;
    final spreadCount = (count + 1) ~/ 2;

    final readDirection = ref.watch(
      commonReaderSettingsProvider(
        seriesId: seriesId,
      ).select(
        (value) => value.requireValue.readDirection,
      ),
    );

    final canScroll = data.navigationGesturesEnabled && !data.reduceAnimations;
    final scrollPhysics = canScroll
        ? const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          )
        : const NeverScrollableScrollPhysics();

    ref.listen(
      navigationProvider.select(
        (state) => state.whenData(
          (data) {
            if (data.page != page || data.fromObserver) return null;

            return spreads ? data.subpage ~/ 2 : data.subpage;
          },
        ),
      ),
      (previous, next) async {
        next.whenData((next) async {
          final previousSubpage = previous?.value;
          if (next == null || next == previousSubpage) {
            return;
          }

          if (controller.hasClients && controller.page?.round() != next) {
            final isSequential =
                previousSubpage != null && (next - previousSubpage).abs() == 1;

            isSequential && !data.reduceAnimations
                ? controller.animateToPage(
                    next,
                    duration: LayoutConstants.pageSlideDuration,
                    curve: Curves.easeInOut,
                  )
                : controller.jumpToPage(next);
          }
        });
      },
    );

    Widget buildColumn(int index) {
      if (index >= data.reflow.subpages.length) {
        if (data.reflow.status == .measuring &&
            index == data.reflow.subpages.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return const SizedBox.shrink();
      }

      return OverflowBox(
        maxHeight: double.infinity,
        alignment: .topCenter,
        child: RenderEpubContent(
          seriesId: seriesId,
          html: data.reflow.subpages[index].outerHtml,
          styles: data.reflow.page.styles,
          imageCache: imageCache,
        ),
      );
    }

    return PageView.builder(
      controller: controller,
      allowImplicitScrolling: true,
      scrollCacheExtent: const .viewport(4),
      reverse: data.reverse,
      itemCount: spreads ? spreadCount : count,
      physics: scrollPhysics,
      onPageChanged: (newPage) {
        if (data.navigation.page != page) return;

        ref
            .read(navigationProvider.notifier)
            .jumpToSubpage(
              spreads ? newPage * 2 : newPage,
              fromObserver: true,
            );
      },
      itemBuilder: (context, index) {
        if (!spreads) {
          return buildColumn(index);
        }

        return Row(
          textDirection: switch (readDirection) {
            .leftToRight => .ltr,
            .rightToLeft => .rtl,
          },
          children: [
            Expanded(child: buildColumn(index * 2)),
            Expanded(child: buildColumn(index * 2 + 1)),
          ],
        );
      },
    );
  }
}
