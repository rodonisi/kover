import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/lists/chapters_grid.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChaptersPage extends HookConsumerWidget {
  final int seriesId;
  final int? volumeId;
  const ChaptersPage({super.key, required this.seriesId, this.volumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideRead = useState(false);
    final sortDirection = useState(SortDirection.ascending);
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        if (volumeId != null) {
          return state.value?.volumes
                  .where((volume) => volume.id == volumeId)
                  .singleOrNull
                  ?.chapters ??
              [];
        }
        return (hideRead.value
                ? state.value?.unreadChapters
                : state.value?.chapters) ??
            [];
      }),
    );

    final toShow = sortDirection.value == .descending
        ? chapters.reversed.toList()
        : chapters;

    return _ChaptersPage(
      title: 'Chapters',
      seriesId: seriesId,
      chapters: toShow,
      action: ContextMenuButton(
        icon: Icon(
          sortDirection.value == .ascending
              ? LucideIcons.arrowDownNarrowWide
              : LucideIcons.arrowDownWideNarrow,
        ),
        menu: _getMenu(hideRead: hideRead, sortDirection: sortDirection),
      ),
    );
  }
}

class StorylinePage extends HookConsumerWidget {
  final int seriesId;
  const StorylinePage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortDirection = useState(SortDirection.ascending);
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        return state.value?.storyline ?? [];
      }),
    );

    final toShow = sortDirection.value == .descending
        ? chapters.reversed.toList()
        : chapters;

    return _ChaptersPage(
      title: 'Storyline',
      seriesId: seriesId,
      chapters: toShow,
      action: ContextMenuButton(
        icon: Icon(
          sortDirection.value == .ascending
              ? LucideIcons.arrowDownNarrowWide
              : LucideIcons.arrowDownWideNarrow,
        ),
        menu: _getMenu(sortDirection: sortDirection),
      ),
    );
  }
}

class SpecialsPage extends HookConsumerWidget {
  final int seriesId;
  const SpecialsPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortDirection = useState(SortDirection.ascending);
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        return state.value?.specials ?? [];
      }),
    );

    final toShow = sortDirection.value == .descending
        ? chapters.reversed.toList()
        : chapters;

    return _ChaptersPage(
      title: 'Specials',
      seriesId: seriesId,
      chapters: toShow,
      action: ContextMenuButton(
        icon: Icon(
          sortDirection.value == .ascending
              ? LucideIcons.arrowDownNarrowWide
              : LucideIcons.arrowDownWideNarrow,
        ),
        menu: _getMenu(sortDirection: sortDirection),
      ),
    );
  }
}

class _ChaptersPage extends HookConsumerWidget {
  final String title;
  final int seriesId;
  final List<ChapterModel> chapters;
  final Widget? action;
  const _ChaptersPage({
    required this.title,
    required this.seriesId,
    required this.chapters,
    this.action,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final filteredChapters = useListenableSelector(controller, () {
      final filter = controller.text;
      if (filter.isEmpty) return chapters;
      return chapters
          .where(
            (chapter) =>
                chapter.title.toLowerCase().contains(filter.toLowerCase()),
          )
          .toList();
    });

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: .onDrag,
          slivers: [
            SliverAppBar.large(
              title: Text(title),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.smallPadding,
              ),
              actions: [
                ?action,
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
              sliver: ChaptersGrid(
                seriesId: seriesId,
                chapters: filteredChapters,
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}

ContextMenu<dynamic> _getMenu({
  ValueNotifier<bool>? hideRead,
  ValueNotifier<SortDirection>? sortDirection,
}) {
  return ContextMenu(
    entries: [
      if (hideRead != null) ...[
        const MenuHeader(text: 'Filter'),
        MenuItem(
          icon: hideRead.value ? const Icon(LucideIcons.check) : null,
          label: const Text('Hide Read'),
          onSelected: (_) => hideRead.value = !hideRead.value,
        ),
      ],
      if (sortDirection != null) ...[
        const MenuHeader(text: 'Sort Direction'),
        MenuItem(
          icon: sortDirection.value == SortDirection.ascending
              ? const Icon(LucideIcons.check)
              : null,
          label: const Text('Ascending'),
          onSelected: (_) => sortDirection.value = SortDirection.ascending,
        ),
        MenuItem(
          icon: sortDirection.value == SortDirection.descending
              ? const Icon(LucideIcons.check)
              : null,
          label: const Text('Descending'),
          onSelected: (_) => sortDirection.value = SortDirection.descending,
        ),
      ],
    ],
  );
}
