import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/pages/home/collapsible_section.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverRecentlyUpdated extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final series = ref.watch(recentlyUpdatedProvider);

    return AsyncSliver(
      asyncValue: series,
      data: (data) => CollapsibleSection<SeriesModel>(
        title: l.recentlyUpdated,
        items: data,
        gridBuilder: (items, rowCount, onCrossAxisCountChanged) =>
            SeriesSliverGrid(
              series: items,
              rowCount: rowCount,
              onCrossAxisCountChanged: onCrossAxisCountChanged,
            ),
      ),
    );
  }
}
