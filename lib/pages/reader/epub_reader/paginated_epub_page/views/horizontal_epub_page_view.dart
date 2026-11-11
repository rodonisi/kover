import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_content.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class HorizontalEpubPageView extends HookWidget {
  final PaginatedEpubPageController controller;
  final PaginatedEpubPageSettings settings;
  final void Function(EpubAnchorTarget)? onAnchorTap;

  const HorizontalEpubPageView({
    super.key,
    required this.controller,
    required this.settings,
    this.onAnchorTap,
  });

  @override
  Widget build(BuildContext context) {
    final viewport = controller.contentViewport;
    if (viewport == null) return const SizedBox.shrink();

    final current = controller.currentSubpage;
    final pageController = usePageController(initialPage: current);

    useEffect(() {
      if (!pageController.hasClients) return null;
      if (pageController.page?.round() == current) return null;

      if (settings.reduceAnimations) {
        pageController.jumpToPage(current);
      } else {
        pageController.animateToPage(
          current,
          duration: LayoutConstants.pageSlideDuration,
          curve: Curves.easeInOut,
        );
      }
      return null;
    }, [current, pageController, settings.reduceAnimations]);

    return PageView.builder(
      controller: pageController,
      itemCount: controller.subpageCount,
      allowImplicitScrolling: true,
      scrollCacheExtent: const .viewport(4),
      physics: settings.canScroll && !settings.reduceAnimations
          ? const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            )
          : const NeverScrollableScrollPhysics(),
      onPageChanged: controller.jumpToSubpage,
      itemBuilder: (context, index) {
        return OverflowBox(
          maxHeight: double.infinity,
          alignment: .topCenter,
          child: PaginatedEpubPageContent(
            html: controller.getSubpage(index),
            settings: settings,
            viewport: viewport,
            cssEngine: controller.cssEngine,
            onAnchorTap: onAnchorTap,
          ),
        );
      },
    );
  }
}
