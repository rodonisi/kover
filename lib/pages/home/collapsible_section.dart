import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/series_sliver_grid.dart';

class CollapsibleSection extends HookConsumerWidget {
  final String title;
  final List<SeriesModel> series;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.series,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAll = useState(false);

    final total = series.length;
    final toShow = showAll.value ? total : 1;

    if (series.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: LayoutConstants.smallEdgeInsets,
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton(
                  onPressed: () {
                    showAll.value = !showAll.value;
                  },
                  child: Text(showAll.value ? 'Show Less' : 'Show All'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsetsGeometry.symmetric(
            horizontal: LayoutConstants.smallPadding,
          ),
          sliver: SeriesSliverGrid(series: series, rowCount: toShow),
        ),
      ],
    );
  }
}
