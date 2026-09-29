import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/list_page/series_list_page.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class OnDeckPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: _OnDeckPageContent(),
      ),
    );
  }
}

class _OnDeckPageContent extends HookConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = useTextEditingController();
    final sortDirection = useState(SortDirection.descending);
    final orderBy = useState(UnorderedSortOption.lastRead);
    final downloadedOnly = useState(false);

    final series = ref.watch(
      onDeckProvider(
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    useListenable(controller);

    return SeriesListPage(
      title: l.onDeck,
      controller: controller,
      sortMenu: UnorderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (sort) => sortDirection.value = sort,
        orderBy: orderBy.value,
        onOrderByChanged: (order) => orderBy.value = order,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
      ),
      series: series,
    );
  }
}
