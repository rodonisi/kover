import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/widgets/sliver_list_page/series_list_page.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class OnDeckPage extends StatelessWidget {
  const OnDeckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: Consumer(
          builder: (context, ref, _) => SeriesListPage(
            title: l.onDeck,
            series: ref.watch(onDeckProvider),
          ),
        ),
      ),
    );
  }
}
