import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/reading_list_card.dart';
import 'package:kover/widgets/cards/series_card.dart';
import 'package:material_ui/material_ui.dart';

class HomeSection<T> extends HookConsumerWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback? onNavigate;

  const HomeSection._({
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.onNavigate,
  });

  static HomeSection<SeriesModel> series({
    required String title,
    required List<SeriesModel> items,
    VoidCallback? onNavigate,
  }) {
    return HomeSection._(
      title: title,
      items: items,
      itemBuilder: (context, item) =>
          SeriesCard(key: ValueKey('$title-${item.id}'), seriesId: item.id),
      onNavigate: onNavigate,
    );
  }

  static HomeSection<ReadingListModel> readingLists({
    required String title,
    required List<ReadingListModel> items,
    VoidCallback? onNavigate,
  }) {
    return HomeSection._(
      title: title,
      items: items,
      itemBuilder: (context, item) =>
          ReadingListCard(key: ValueKey(item.id), readingListId: item.id),
      onNavigate: onNavigate,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final total = items.length;

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: LayoutConstants.smallEdgeInsets,
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                InkWell(
                  borderRadius: .circular(LayoutConstants.largeBorderRadius),
                  onTap: onNavigate,
                  child: Padding(
                    padding: const .symmetric(
                      horizontal: LayoutConstants.smallPadding,
                      vertical: LayoutConstants.smallestPadding,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      spacing: LayoutConstants.smallPadding,
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        Icon(
                          KoverIcons.chevronRight,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(
                            0xdd,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _SectionCarousel(
            itemCount: total,
            itemBuilder: (context, index) => AspectRatio(
              aspectRatio: LayoutConstants.chapterCardAspectRatio,
              child: itemBuilder(context, items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCarousel extends ConsumerWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _SectionCarousel({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossAxisCount = ref
        .watch(breakpointsProvider)
        .adaptiveCrossAxisCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth - LayoutConstants.smallPadding * 2) /
            crossAxisCount /
            LayoutConstants.chapterCardAspectRatio;

        return SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: .horizontal,
            padding: const .symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            itemBuilder: itemBuilder,
            itemCount: itemCount,
          ),
        );
      },
    );
  }
}
