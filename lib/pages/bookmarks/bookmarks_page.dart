import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/list_page/series_list_page.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

/// A filterable list of every series that has bookmarks. Tapping a series
/// opens its bookmark gallery; the context menu offers the series details.
class BookmarksPage extends HookConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orderBy = useState(UnorderedSortOption.name);
    final sortDirection = useState(SortDirection.ascending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    final query = ref.watch(
      filterSeriesProvider(
        controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
        bookmarkedOnly: true,
      ),
    );

    useListenable(controller);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: LoginGuard(
        child: SeriesListPage(
          title: l.bookmarks,
          controller: controller,
          series: query,
          hideAction: true,
          onSeriesTap: (series) =>
              SeriesBookmarksRoute(seriesId: series.id).push(context),
          onViewDetails: (series) =>
              SeriesDetailRoute(seriesId: series.id).push(context),
          sortMenu: UnorderedSortMenu(
            sortDirection: sortDirection.value,
            onSortDirectionChanged: (value) => sortDirection.value = value,
            orderBy: orderBy.value,
            onOrderByChanged: (value) => orderBy.value = value,
            hideRead: hideRead.value,
            onHideReadChanged: (value) => hideRead.value = value,
            downloadedOnly: downloadedOnly.value,
            onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
          ),
        ),
      ),
    );
  }
}
