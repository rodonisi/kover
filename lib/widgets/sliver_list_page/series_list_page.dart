import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/lists/series_sliver_grid.dart';
import 'package:kover/widgets/sliver_list_page/sliver_page_shell.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SeriesListPage extends HookConsumerWidget {
  final String title;
  final AsyncValue<List<SeriesModel>> series;

  const SeriesListPage({
    super.key,
    required this.title,
    required this.series,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortDirection = useState<SortDirection?>(null);
    final controller = useTextEditingController();

    useListenable(controller);

    return SliverPageShell(
      title: title,
      filterController: controller,
      appBarActions: [
        ContextMenuButton(
          icon: Icon(
            switch (sortDirection.value) {
              .descending => KoverIcons.descending,
              _ => KoverIcons.ascending,
            },
          ),
          menu: _menu(sortDirection: sortDirection, context: context),
        ),
      ],
      slivers: [
        AsyncSliver(
          asyncValue: series,
          data: (data) {
            final filteredData = _filtered(data, controller.text);
            final sortedData = _sorted(filteredData, sortDirection.value);

            return SliverPadding(
              padding: LayoutConstants.smallEdgeInsets,
              sliver: SeriesSliverGrid(series: sortedData),
            );
          },
        ),
      ],
    );
  }

  List<SeriesModel> _filtered(List<SeriesModel> data, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return data;
    }

    return data.where((series) {
      final name = series.name.toLowerCase();
      return name.contains(q);
    }).toList();
  }

  List<SeriesModel> _sorted(
    List<SeriesModel> data,
    SortDirection? direction,
  ) {
    if (direction == null) {
      return data;
    }

    final sorted = [...data]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (direction == .descending) {
      return sorted.reversed.toList();
    }

    return sorted;
  }

  ContextMenu _menu({
    required ValueNotifier<SortDirection?> sortDirection,
    required BuildContext context,
  }) {
    final l = AppLocalizations.of(context);
    return ContextMenu(
      entries: <ContextMenuEntry>[
        MenuHeader(text: l.sortBy),
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
