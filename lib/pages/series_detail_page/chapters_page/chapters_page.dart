import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/widgets/list_page/chapters_list_page.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:material_ui/material_ui.dart';

class ChaptersPage extends HookConsumerWidget {
  final int seriesId;
  final int? volumeId;
  const ChaptersPage({super.key, required this.seriesId, this.volumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final sortDirection = useState(SortDirection.ascending);
    final orderBy = useState(OrderedSortOption.sortOrder);
    final controller = useTextEditingController();

    useListenable(controller);

    final chapters = ref.watch(
      filteredChaptersProvider(
        seriesId: seriesId,
        volumeId: volumeId,
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    return _ChaptersPage(
      title: l.chapters,
      chapters: chapters,
      controller: controller,
      action: OrderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (newDirection) =>
            sortDirection.value = newDirection,
        orderBy: orderBy.value,
        onOrderByChanged: (value) => orderBy.value = value,
        hideRead: hideRead.value,
        onHideReadChanged: (newHideRead) => hideRead.value = newHideRead,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
      ),
    );
  }
}

class StorylinePage extends HookConsumerWidget {
  final int seriesId;
  const StorylinePage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orderBy = useState(OrderedSortOption.sortOrder);
    final sortDirection = useState(SortDirection.ascending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    useListenable(controller);

    final chapters = ref.watch(
      filteredChaptersProvider(
        seriesId: seriesId,
        kind: .storyline,
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    return _ChaptersPage(
      title: l.storyline,
      chapters: chapters,
      controller: controller,
      action: OrderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (value) => sortDirection.value = value,
        orderBy: orderBy.value,
        onOrderByChanged: (value) => orderBy.value = value,
        hideRead: hideRead.value,
        onHideReadChanged: (value) => hideRead.value = value,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
      ),
    );
  }
}

class SpecialsPage extends HookConsumerWidget {
  final int seriesId;
  const SpecialsPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orderBy = useState(OrderedSortOption.sortOrder);
    final sortDirection = useState(SortDirection.ascending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    useListenable(controller);

    final chapters = ref.watch(
      filteredChaptersProvider(
        seriesId: seriesId,
        kind: .specials,
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    return _ChaptersPage(
      title: l.specials,
      chapters: chapters,
      controller: controller,
      action: OrderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (newDirection) =>
            sortDirection.value = newDirection,
        orderBy: orderBy.value,
        onOrderByChanged: (newOrderBy) => orderBy.value = newOrderBy,
        hideRead: hideRead.value,
        onHideReadChanged: (newHideRead) => hideRead.value = newHideRead,
        downloadedOnly: downloadedOnly.value,
        onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
      ),
    );
  }
}

class _ChaptersPage extends HookConsumerWidget {
  final String title;
  final AsyncValue<List<ChapterModel>> chapters;
  final TextEditingController controller;
  final Widget? action;
  const _ChaptersPage({
    required this.title,
    required this.chapters,
    required this.controller,
    this.action,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: ChaptersListPage(
        title: title,
        controller: controller,
        sortMenu: action,
        chapters: chapters,
      ),
    );
  }
}
