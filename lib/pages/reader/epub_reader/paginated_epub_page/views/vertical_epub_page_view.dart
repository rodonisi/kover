import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_content.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class VerticalEpubPageView extends HookWidget {
  final PaginatedEpubPageController controller;
  final PaginatedEpubPageSettings settings;

  const VerticalEpubPageView({
    super.key,
    required this.controller,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final viewport = controller.contentViewport;
    if (viewport == null) return const SizedBox.shrink();

    final current = controller.currentSubpage;
    final scrollController = useScrollController();
    final observed = useRef<int?>(null);
    final observerController = useMemoized(() {
      final initialModel = ObserverIndexPositionModel(index: current);
      final created = SliverObserverController(controller: scrollController);
      created.initialIndexModelBlock = () => initialModel;
      created.cacheJumpIndexOffset = false;
      return created;
    }, [scrollController]);

    useEffect(
      () {
        if (!scrollController.hasClients) return null;

        if (observed.value == current) {
          observed.value = null;
          return null;
        }

        if (settings.reduceAnimations) {
          observerController.jumpTo(index: current);
        } else {
          observerController.animateTo(
            index: current,
            duration: LayoutConstants.pageSlideDuration,
            curve: Curves.easeInOut,
          );
        }
        return null;
      },
      [
        current,
        scrollController,
        observerController,
        settings.reduceAnimations,
      ],
    );

    return SliverViewObserver(
      controller: observerController,
      onObserve: (model) {
        if (model is! ListViewObserveModel) return;

        final firstVisible = model.firstChild?.index;
        if (firstVisible == null) return;

        final last = controller.subpageCount - 1;
        final target =
            last >= 0 && model.displayingChildIndexList.contains(last)
            ? last
            : firstVisible;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (target == controller.currentSubpage) return;
          observed.value = target;
          controller.jumpToSubpage(target.clamp(0, last));
        });
      },
      child: CustomScrollView(
        controller: scrollController,
        physics: settings.canScroll
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const NeverScrollableScrollPhysics(),
        slivers: [
          if (settings.ignoreSafeArea)
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.top,
              ),
            ),
          SliverList.builder(
            itemCount: controller.subpageCount,
            itemBuilder: (context, index) {
              return PaginatedEpubPageContent(
                html: controller.getSubpage(index),
                settings: settings,
                viewport: viewport,
                cssEngine: controller.cssEngine,
              );
            },
          ),
        ],
      ),
    );
  }
}
