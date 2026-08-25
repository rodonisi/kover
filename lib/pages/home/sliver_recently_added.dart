import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/home/home_section.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/cards/series_card.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverRecentlyAdded extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final series = ref.watch(recentlyAddedProvider);

    return AsyncSliver(
      asyncValue: series,
      data: (data) {
        return HomeSection.series(
          title: l.recentlyAdded,
          items: data,
          itemBuilder: (context, item) =>
              SeriesCard(key: ValueKey(item.id), seriesId: item.id),
          onNavigate: () => const RecentlyAddedRoute().push(context),
        );
      },
    );
  }
}
