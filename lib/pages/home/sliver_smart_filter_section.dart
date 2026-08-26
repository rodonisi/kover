import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/home/home_section.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/smart_filter.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverSmartFilterSection extends ConsumerWidget {
  final int smartFilterId;

  const new({
    super.key,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartFilter = ref.watch(smartFilterProvider(id: smartFilterId));

    return AsyncSliver(
      asyncValue: smartFilter,
      data: (data) {
        return switch (data.type) {
          .series => _SmartFilterSeriesSection(
            title: data.name,
            smartFilterId: smartFilterId,
          ),
          .readingList => _SmartFilterReadingListsSection(
            title: data.name,
            smartFilterId: smartFilterId,
          ),
          _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
        };
      },
    );
  }
}

class _SmartFilterSeriesSection extends ConsumerWidget {
  final String title;
  final int smartFilterId;

  const new({
    required this.title,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(
      smartFilterSeriesProvider(smartFilterId: smartFilterId),
    );

    return AsyncSliver(
      asyncValue: series,
      data: (data) => HomeSection.series(
        title: title,
        items: data,
        onNavigate: () =>
            SmartFilterRoute(smartFilterId: smartFilterId).push(context),
      ),
    );
  }
}

class _SmartFilterReadingListsSection extends ConsumerWidget {
  final String title;
  final int smartFilterId;

  const _SmartFilterReadingListsSection({
    required this.title,
    required this.smartFilterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingLists = ref.watch(
      smartFilterReadingListsProvider(smartFilterId: smartFilterId),
    );

    return AsyncSliver(
      asyncValue: readingLists,
      data: (data) => HomeSection.readingLists(
        title: title,
        items: data,
        onNavigate: () =>
            SmartFilterRoute(smartFilterId: smartFilterId).push(context),
      ),
    );
  }
}
