import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/smart_filter.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:kover/widgets/list_page/reading_lists_list_page.dart';
import 'package:kover/widgets/list_page/series_list_page.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class SmartFilterPage extends HookConsumerWidget {
  final int smartFilterId;

  const new({
    super.key,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(smartFilterProvider(id: smartFilterId));

    return Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: Async(
          asyncValue: filter,
          data: (data) => switch (data.type) {
            .series => _SmartFilterSeriesContent(
              smartFilterId: smartFilterId,
              title: data.name,
            ),
            .readingList => _SmartFilterReadingListsContent(
              smartFilterId: smartFilterId,
              title: data.name,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _SmartFilterReadingListsContent extends HookConsumerWidget {
  final int smartFilterId;
  final String title;

  const new({
    required this.smartFilterId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final orderBy = useState(UnorderedSortOption.name);
    final sortDirection = useState(SortDirection.ascending);

    final readingLists = ref.watch(
      smartFilterReadingListsProvider(
        smartFilterId: smartFilterId,
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
      ),
    );

    useListenable(controller);

    return ReadingListsListPage(
      title: title,
      controller: controller,
      sortMenu: UnorderedSortMenu(
        orderBy: orderBy.value,
        onOrderByChanged: (value) => orderBy.value = value,
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (value) => sortDirection.value = value,
      ),
      readingLists: readingLists,
    );
  }
}

class _SmartFilterSeriesContent extends HookConsumerWidget {
  final int smartFilterId;
  final String title;

  const new({
    required this.smartFilterId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBy = useState(UnorderedSortOption.name);
    final sortDirection = useState(SortDirection.ascending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    useListenable(controller);

    final series = ref.watch(
      smartFilterSeriesProvider(
        smartFilterId: smartFilterId,
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    return SeriesListPage(
      title: title,
      controller: controller,
      sortMenu: UnorderedSortMenu(
        orderBy: orderBy.value,
        onOrderByChanged: (value) => orderBy.value = value,
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (value) => sortDirection.value = value,
        hideRead: hideRead.value,
        onHideReadChanged: (value) => hideRead.value = value,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
      ),
      series: series,
    );
  }
}
