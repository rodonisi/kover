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

class RecentlyAddedPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: _RecentlyAddedPageContent(),
      ),
    );
  }
}

class _RecentlyAddedPageContent extends HookConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orderBy = useState(UnorderedSortOption.dateAdded);
    final sortDirection = useState(SortDirection.descending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    useListenable(controller);

    final series = ref.watch(
      recentlyAddedProvider(
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    return SeriesListPage(
      title: l.recentlyAdded,
      controller: controller,
      sortMenu: UnorderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (sort) => sortDirection.value = sort,
        orderBy: orderBy.value,
        onOrderByChanged: (order) => orderBy.value = order,
        hideRead: hideRead.value,
        onHideReadChanged: (hide) => hideRead.value = hide,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (hide) => downloadedOnly.value = hide,
      ),
      series: series,
    );
  }
}
