import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/series_sort_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

class AllSeriesPage extends StatelessWidget {
  const AllSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SeriesPage(title: l.allSeries);
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

class CollectionSeriesPage extends ConsumerWidget {
  final int collectionId;

  const CollectionSeriesPage({
    super.key,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(
      collectionProvider(collectionId: collectionId),
    );
    return Async(
      asyncValue: collection,
      data: (data) {
        return SeriesPage(
          title: data.title,
          collectionId: data.id,
        );
      },
    );
  }
}

class SeriesPage extends HookConsumerWidget {
  final String title;
  final String? subtitle;
  final int? libraryId;
  final int? collectionId;

  const SeriesPage({
    super.key,
    required this.title,
    this.subtitle,
    this.libraryId,
    this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortOption = useState(SeriesSortOption.name);
    final sortDirection = useState(SortDirection.ascending);
    final controller = useTextEditingController();

    final allSeries = ref.watch(
      allSeriesProvider(
        libraryId: libraryId,
        collectionId: collectionId,
        orderByName: sortOption.value == .name,
        orderByRecentlyAdded: sortOption.value == .dateAdded,
        orderByRecentlyUpdated: sortOption.value == .lastModified,
        ascending: sortDirection.value == .ascending,
      ),
    );
    final query = ref.watch(
      filterSeriesProvider(
        controller.text,
        libraryId: libraryId,
        collectionId: collectionId,
        orderByName: sortOption.value == .name,
        orderByRecentlyAdded: sortOption.value == .dateAdded,
        orderByRecentlyUpdated: sortOption.value == .lastModified,
        ascending: sortDirection.value == .ascending,
      ),
    );

    useListenable(controller);

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: .onDrag,
        slivers: [
          SliverAppBar.large(
            title: Text(title),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            actions: [
              ContextMenuButton(
                icon: Icon(
                  sortDirection.value == .ascending
                      ? LucideIcons.arrowDownNarrowWide
                      : LucideIcons.arrowDownWideNarrow,
                ),
                menu: _menu(
                  sortOption: sortOption,
                  sortDirection: sortDirection,
                  context: context,
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.mediumPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: FilterInputField(controller: controller),
            ),
          ),
          AsyncSliver(
            asyncValue: allSeries,
            data: (data) {
              return AsyncSliver(
                asyncValue: query,
                data: (search) {
                  final filteredData = controller.text.isEmpty ? data : search;
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

  ContextMenu _menu({
    required ValueNotifier<SeriesSortOption> sortOption,
    required ValueNotifier<SortDirection> sortDirection,
    required BuildContext context,
  }) {
    final l = AppLocalizations.of(context);
    return ContextMenu(
      entries: <ContextMenuEntry>[
        MenuHeader(text: l.sortBy),
        MenuItem(
          label: Text(l.name),
          icon: _getItemIcon(sortOption.value == .name),
          onSelected: (_) {
            sortOption.value = .name;
          },
        ),
        MenuItem(
          label: Text(l.dateAdded),
          icon: _getItemIcon(sortOption.value == .dateAdded),
          onSelected: (_) {
            sortOption.value = .dateAdded;
          },
        ),
        MenuItem(
          label: Text(l.lastModified),
          icon: _getItemIcon(sortOption.value == .lastModified),
          onSelected: (_) {
            sortOption.value = .lastModified;
          },
        ),
        MenuHeader(text: l.sortDirection),
        MenuItem(
          label: Text(l.ascending),
          icon: _getItemIcon(sortDirection.value == .ascending),
          onSelected: (_) {
            sortDirection.value = .ascending;
          },
        ),
        MenuItem(
          label: Text(l.descending),
          icon: _getItemIcon(sortDirection.value == .descending),
          onSelected: (_) {
            sortDirection.value = .descending;
          },
        ),
      ],
    );
  }

  Icon? _getItemIcon(bool selected) {
    return selected ? const Icon(LucideIcons.check) : null;
  }
}
