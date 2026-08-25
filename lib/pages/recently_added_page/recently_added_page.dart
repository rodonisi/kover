import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/widgets/sliver_list_page/series_list_page.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class RecentlyAddedPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: Consumer(
          builder: (context, ref, _) {
            final series = ref.watch(recentlyAddedProvider);
            return Async(
              asyncValue: series,
              data: (data) =>
                  SeriesListPage(title: l.recentlyAdded, series: data),
            );
          },
        ),
      ),
    );
  }
}
