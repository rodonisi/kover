import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/layout_constants.dart';

class CollapsibleSection<T> extends HookConsumerWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String Function(BuildContext context, int count) countLabelBuilder;
  final VoidCallback? onNavigate;

  const CollapsibleSection._({
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.countLabelBuilder,
    this.onNavigate,
  });

  static CollapsibleSection<SeriesModel> series({
    required String title,
    required List<SeriesModel> items,
    required Widget Function(BuildContext context, SeriesModel item)
    itemBuilder,
    VoidCallback? onNavigate,
  }) {
    return CollapsibleSection._(
      title: title,
      items: items,
      itemBuilder: itemBuilder,
      countLabelBuilder: (context, total) =>
          AppLocalizations.of(context).seriesCount(total),
      onNavigate: onNavigate,
    );
  }

  static CollapsibleSection<ReadingListModel> readingLists({
    required String title,
    required List<ReadingListModel> items,
    required Widget Function(BuildContext context, ReadingListModel item)
    itemBuilder,
    VoidCallback? onNavigate,
  }) {
    return CollapsibleSection._(
      title: title,
      items: items,
      itemBuilder: itemBuilder,
      countLabelBuilder: (context, total) =>
          AppLocalizations.of(context).readingListsCount(total),
      onNavigate: onNavigate,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showGrid = useState(false);

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
              spacing: LayoutConstants.smallPadding,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => showGrid.value = !showGrid.value,
                  icon: Icon(
                    showGrid.value ? KoverIcons.carousel : KoverIcons.grid,
                  ),
                ),
                if (onNavigate != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(
                      LayoutConstants.largeBorderRadius,
                    ),
                    onTap: onNavigate,
                    child: Padding(
                      padding: const .all(
                        LayoutConstants.smallPadding,
                      ),
                      child: Row(
                        mainAxisSize: .min,
                        children: [
                          Text(
                            countLabelBuilder(context, total),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(
                            width: LayoutConstants.smallestPadding,
                          ),
                          const Icon(KoverIcons.chevronRight),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!showGrid.value)
          SliverToBoxAdapter(
            child: _SectionCarousel(
              itemCount: total,
              itemBuilder: (context, index) => AspectRatio(
                aspectRatio: LayoutConstants.chapterCardAspectRatio,
                child: itemBuilder(context, items[index]),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsetsGeometry.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            sliver: AdaptiveSliverGrid(
              itemCount: total,
              builder: (context, index) => itemBuilder(context, items[index]),
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
            padding: const EdgeInsets.symmetric(
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
