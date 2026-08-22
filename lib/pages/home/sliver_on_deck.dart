import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/pages/home/collapsible_section.dart';
import 'package:kover/pages/home/on_deck_scope.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverOnDeck extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final onDeck = ref.watch(onDeckProvider);

    return AsyncSliver(
      asyncValue: onDeck,
      data: (data) => OnDeckScope(
        child: CollapsibleSection<SeriesModel>(
          title: l.onDeck,
          items: data,
          gridBuilder: (items, rowCount, onCrossAxisCountChanged) =>
              SeriesSliverGrid(
                series: items,
                rowCount: rowCount,
                onCrossAxisCountChanged: onCrossAxisCountChanged,
              ),
        ),
      ),
    );
  }
}
