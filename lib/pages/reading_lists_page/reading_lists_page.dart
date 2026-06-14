import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/reading_lists_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class ReadingListsPage extends HookConsumerWidget {
  const ReadingListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sortDirection = useState(SortDirection.ascending);
    final controller = useTextEditingController();
    final readingLists = ref.watch(readingListsProvider);

    useListenable(controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider.notifier).syncReadingLists();
    });

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: .onDrag,
        slivers: [
          SliverAppBar.large(
            title: Text(l.readingLists),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            actions: [
              ContextMenuButton(
                icon: Icon(
                  sortDirection.value == .ascending
                      ? KoverIcons.ascending
                      : KoverIcons.descending,
                ),
                menu: _menu(sortDirection: sortDirection, context: context),
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
            asyncValue: readingLists,
            data: (data) {
              final filteredData = _filteredReadingLists(
                data: data,
                query: controller.text,
              );
              final sortedData = _sortedReadinglists(
                data: filteredData,
                direction: sortDirection.value,
              );

              return SliverPadding(
                padding: LayoutConstants.smallEdgeInsets,
                sliver: ReadingListsSliverGrid(readingLists: sortedData),
              );
            },
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }

  List<ReadingListModel> _filteredReadingLists({
    required List<ReadingListModel> data,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return data;
    }

    return data.where((collection) {
      final title = collection.title.toLowerCase();
      final summary = collection.summary?.toLowerCase();
      return title.contains(q) || (summary?.contains(q) ?? false);
    }).toList();
  }

  List<ReadingListModel> _sortedReadinglists({
    required List<ReadingListModel> data,
    required SortDirection direction,
  }) {
    final sorted = [...data];
    sorted.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    if (direction == SortDirection.descending) {
      return sorted.reversed.toList();
    }

    return sorted;
  }

  ContextMenu _menu({
    required ValueNotifier<SortDirection> sortDirection,
    required BuildContext context,
  }) {
    final l = AppLocalizations.of(context);
    return ContextMenu(
      entries: <ContextMenuEntry>[
        MenuHeader(text: l.sortDirection),
        MenuItem(
          label: Text(l.ascending),
          icon: _getItemIcon(
            sortDirection.value == .ascending,
          ),
          onSelected: (_) {
            sortDirection.value = .ascending;
          },
        ),
        MenuItem(
          label: Text(l.descending),
          icon: _getItemIcon(
            sortDirection.value == .descending,
          ),
          onSelected: (_) {
            sortDirection.value = .descending;
          },
        ),
      ],
    );
  }

  Icon? _getItemIcon(bool selected) {
    return selected ? const Icon(KoverIcons.check) : null;
  }
}
