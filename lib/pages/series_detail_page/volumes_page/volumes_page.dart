import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/volume_card.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VolumesPage extends HookConsumerWidget {
  final int seriesId;
  const VolumesPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hideRead = useState(false);
    final sortDirection = useState(SortDirection.ascending);
    final controller = useTextEditingController();
    useListenable(controller);

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: .onDrag,
          slivers: [
            SliverAppBar.large(
              title: Text(l.volumes),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.smallPadding,
              ),
              actions: [
                ContextMenuButton(
                  menu: _getMenu(
                    hideRead: hideRead,
                    sortDirection: sortDirection,
                    context: context,
                  ),
                  icon: Icon(
                    sortDirection.value == .ascending
                        ? LucideIcons.arrowDownNarrowWide
                        : LucideIcons.arrowDownWideNarrow,
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
            SliverPadding(
              padding: LayoutConstants.smallEdgeInsets,
              sliver: _VolumeGrid(
                seriesId: seriesId,
                hideRead: hideRead.value,
                filter: controller.text,
                descending: sortDirection.value == .descending,
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }

  ContextMenu<dynamic> _getMenu({
    required ValueNotifier<bool> hideRead,
    required ValueNotifier<SortDirection> sortDirection,
    required BuildContext context,
  }) {
    final l = AppLocalizations.of(context);
    return ContextMenu(
      entries: [
        MenuHeader(text: l.filter),
        MenuItem(
          icon: hideRead.value ? const Icon(LucideIcons.check) : null,
          label: Text(l.hideRead),
          onSelected: (_) => hideRead.value = !hideRead.value,
        ),
        MenuHeader(text: l.sortDirection),
        MenuItem(
          icon: sortDirection.value == SortDirection.ascending
              ? const Icon(LucideIcons.check)
              : null,
          label: Text(l.ascending),
          onSelected: (_) => sortDirection.value = SortDirection.ascending,
        ),
        MenuItem(
          icon: sortDirection.value == SortDirection.descending
              ? const Icon(LucideIcons.check)
              : null,
          label: Text(l.descending),
          onSelected: (_) => sortDirection.value = SortDirection.descending,
        ),
      ],
    );
  }
}

class _VolumeGrid extends HookConsumerWidget {
  final int seriesId;
  final bool hideRead;
  final String? filter;
  final bool descending;

  const _VolumeGrid({
    required this.seriesId,
    this.hideRead = false,
    this.filter,
    this.descending = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select(
        (state) =>
            (hideRead ? state.value?.unreadVolumes : state.value?.volumes) ??
            [],
      ),
    );

    var filteredVolumes = (filter == null || filter!.isEmpty)
        ? volumes
        : volumes
              .where(
                (v) => v.name.toLowerCase().contains(filter!.toLowerCase()),
              )
              .toList();

    if (descending) {
      filteredVolumes = filteredVolumes.reversed.toList();
    }

    return AdaptiveSliverGrid(
      itemCount: filteredVolumes.length,
      builder: (context, index) {
        final volume = filteredVolumes[index];
        return VolumeCard(volumeId: volume.id);
      },
    );
  }
}
