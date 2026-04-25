import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/sliver_bottom_padding.dart';

class AllSeriesPage extends StatelessWidget {
  const AllSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SeriesPage(title: 'All Series');
  }
}

class LibrarySeriesPage extends ConsumerWidget {
  final int libraryId;

  const LibrarySeriesPage({
    super.key,
    required this.libraryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider(libraryId: libraryId));
    return Async(
      asyncValue: library,
      data: (data) {
        return SeriesPage(
          title: data.name,
          libraryId: data.id,
        );
      },
    );
  }
}

class SeriesPage extends HookConsumerWidget {
  final String title;
  final String? subtitle;
  final int? libraryId;
  const SeriesPage({
    super.key,
    required this.title,
    this.subtitle,
    this.libraryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(allSeriesProvider(libraryId: libraryId));
    final controller = useTextEditingController();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(title)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.mediumPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: FilterInputField(controller: controller),
            ),
          ),
          AsyncSliver(
            asyncValue: series,
            data: (data) {
              return HookBuilder(
                builder: (context) {
                  final filteredData = useListenableSelector(controller, () {
                    final text = controller.text;
                    if (text.isEmpty) return data;

                    return data
                        .where(
                          (series) => series.name.toLowerCase().contains(
                            text.toLowerCase(),
                          ),
                        )
                        .toList();
                  });
                  return SliverPadding(
                    padding: LayoutConstants.smallEdgeInsets,
                    sliver: SeriesSliverGrid(
                      series: filteredData,
                    ),
                  );
                },
              );
            },
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
