import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_constants.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_content.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:material_ui/material_ui.dart';

class HorizontalEpubPageView extends HookWidget {
  final PaginatedEpubPageController controller;
  final PaginatedEpubPageSettings settings;

  const HorizontalEpubPageView({
    super.key,
    required this.controller,
    required this.settings,
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
          duration: PaginatedEpubPageConstants.pageSlideDuration,
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
          ),
        );
      },
    );
  }
}
