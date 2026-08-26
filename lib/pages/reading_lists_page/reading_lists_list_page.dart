import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/lists/reading_lists_sliver_grid.dart';
import 'package:kover/widgets/sliver_list_page/sliver_page_shell.dart';
import 'package:material_ui/material_ui.dart';

class ReadingListsListPage extends HookConsumerWidget {
  final String title;
  final List<ReadingListModel> readingLists;

  const new({
    super.key,
    required this.title,
    required this.readingLists,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortDirection = useState(SortDirection.ascending);
    final controller = useTextEditingController();

    useListenable(controller);

    final filteredData = _filteredReadingLists(
      data: readingLists,
      query: controller.text,
    );
    final sortedData = _sortedReadingLists(
      data: filteredData,
      direction: sortDirection.value,
    );

    return SliverPageShell(
      title: title,
      filterController: controller,
      appBarActions: [
        ContextMenuButton(
          icon: Icon(
            sortDirection.value == .ascending
                ? KoverIcons.ascending
                : KoverIcons.descending,
          ),
          menu: _menu(sortDirection: sortDirection, context: context),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: LayoutConstants.smallEdgeInsets,
          sliver: ReadingListsSliverGrid(readingLists: sortedData),
        ),
      ],
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

    return data.where((readingList) {
      final title = readingList.title.toLowerCase();
      final summary = readingList.summary?.toLowerCase();
      return title.contains(q) || (summary?.contains(q) ?? false);
    }).toList();
  }

  List<ReadingListModel> _sortedReadingLists({
    required List<ReadingListModel> data,
    required SortDirection direction,
  }) {
    final sorted = [...data]
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

    if (direction == .descending) {
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
    return selected ? const Icon(KoverIcons.check) : null;
  }
}
