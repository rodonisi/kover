import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/collection_model.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/collections_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(child: CollectionsPageContent()),
    );
  }
}

class CollectionsPageContent extends HookConsumerWidget {
  const CollectionsPageContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sortDirection = useState(SortDirection.ascending);
    final controller = useTextEditingController();
    final collections = ref.watch(collectionsProvider);

    useListenable(controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider.notifier).syncCollections();
    });

    return CustomScrollView(
      keyboardDismissBehavior: .onDrag,
      slivers: [
        SliverAppBar.large(
          title: Text(l.collections),
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
          asyncValue: collections,
          data: (data) {
            final filteredData = _filteredCollections(
              data: data,
              query: controller.text,
            );
            final sortedData = _sortedCollections(
              data: filteredData,
              direction: sortDirection.value,
            );

            return SliverPadding(
              padding: LayoutConstants.smallEdgeInsets,
              sliver: CollectionsSliverGrid(collections: sortedData),
            );
          },
        ),
        const SliverBottomPadding(),
      ],
    );
  }

  List<CollectionModel> _filteredCollections({
    required List<CollectionModel> data,
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

  List<CollectionModel> _sortedCollections({
    required List<CollectionModel> data,
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
    return selected ? const Icon(LucideIcons.check) : null;
  }
}
