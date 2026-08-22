import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/pages/home/collapsible_section.dart';
import 'package:kover/riverpod/providers/smart_filter.dart';
import 'package:kover/widgets/lists/reading_lists_sliver_grid.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverSmartFilterSection extends ConsumerWidget {
  final int smartFilterId;

  const new({
    super.key,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartFilter = ref.watch(smartFilterProvider(id: smartFilterId));

    return AsyncSliver(
      asyncValue: smartFilter,
      data: (data) {
        return switch (data.type) {
          .series => _SmartFilterSeriesSection(
            title: data.name,
            smartFilterId: smartFilterId,
          ),
          .readingList => _SmartFilterReadingListsSection(
            title: data.name,
            smartFilterId: smartFilterId,
          ),
          _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
        };
      },
    );
  }
}

class _SmartFilterSeriesSection extends ConsumerWidget {
  final String title;
  final int smartFilterId;

  const new({
    required this.title,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(
      smartFilterSeriesProvider(smartFilterId: smartFilterId),
    );

    return AsyncSliver(
      asyncValue: series,
      data: (data) => CollapsibleSection<SeriesModel>(
        title: title,
        items: data,
        gridBuilder:
            (
              items,
              rowCount,
              onCrossAxisCountChanged,
            ) => SeriesSliverGrid(
              series: items,
              rowCount: rowCount,
              onCrossAxisCountChanged: onCrossAxisCountChanged,
            ),
      ),
    );
  }
}

class _SmartFilterReadingListsSection extends ConsumerWidget {
  final String title;
  final int smartFilterId;

  const _SmartFilterReadingListsSection({
    required this.title,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingLists = ref.watch(
      smartFilterReadingListsProvider(smartFilterId: smartFilterId),
    );

    return AsyncSliver(
      asyncValue: readingLists,
      data: (data) => CollapsibleSection<ReadingListModel>(
        title: title,
        items: data,
        gridBuilder:
            (
              items,
              rowCount,
              onCrossAxisCountChanged,
            ) => ReadingListsSliverGrid(
              readingLists: items,
              rowCount: rowCount,
              onCrossAxisCountChanged: onCrossAxisCountChanged,
            ),
      ),
    );
  }
}
