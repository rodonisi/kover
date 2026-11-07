import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_content.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class SpreadsEpubPageView extends HookWidget {
  final PaginatedEpubPageController controller;
  final PaginatedEpubPageSettings settings;

  const SpreadsEpubPageView({
    super.key,
    required this.controller,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final viewport = controller.contentViewport;
    if (viewport == null) return const SizedBox.shrink();

    final current = controller.currentSubpage ~/ 2;
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
      itemCount: (controller.subpageCount + 1) ~/ 2,
      allowImplicitScrolling: true,
      scrollCacheExtent: const .viewport(4),
      physics: settings.canScroll && !settings.reduceAnimations
          ? const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            )
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) => controller.jumpToSubpage(index * 2),
      itemBuilder: (context, index) {
        return Row(
          children: [
            Expanded(child: _column(index * 2, viewport)),
            Expanded(child: _column(index * 2 + 1, viewport)),
          ],
        );
      },
    );
  }

  Widget _column(int index, Size viewport) {
    if (index >= controller.subpageCount) return const SizedBox.shrink();

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
  }
}
