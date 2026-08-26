import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reading_lists_page/reading_lists_list_page.dart';
import 'package:kover/widgets/sliver_list_page/series_list_page.dart';
import 'package:kover/riverpod/providers/smart_filter.dart';
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
            .series => Async(
              asyncValue: ref.watch(
                smartFilterSeriesProvider(smartFilterId: smartFilterId),
              ),
              data: (series) {
                return SeriesListPage(
                  title: data.name,
                  series: series,
                  defaultSortDirection: .ascending,
                );
              },
            ),
            .readingList => Async(
              asyncValue: ref.watch(
                smartFilterReadingListsProvider(smartFilterId: smartFilterId),
              ),
              data: (readingLists) {
                return ReadingListsListPage(
                  title: data.name,
                  readingLists: readingLists,
                );
              },
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}
