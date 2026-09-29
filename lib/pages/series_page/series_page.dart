import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/list_page/series_list_page.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class AllSeriesPage extends StatelessWidget {
  const AllSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: LoginGuard(
        child: SeriesPage(title: l.allSeries),
      ),
    );
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
    final orderBy = useState(UnorderedSortOption.name);
    final sortDirection = useState(SortDirection.ascending);
    final hideRead = useState(false);
    final downloadedOnly = useState(false);
    final controller = useTextEditingController();

    final query = ref.watch(
      filterSeriesProvider(
        controller.text,
        libraryId: libraryId,
        collectionId: collectionId,
        orderBy: orderBy.value,
        direction: sortDirection.value,
        hideRead: hideRead.value,
        downloadedOnly: downloadedOnly.value,
      ),
    );

    useListenable(controller);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SeriesListPage(
        title: title,
        controller: controller,
        sortMenu: UnorderedSortMenu(
          sortDirection: sortDirection.value,
          onSortDirectionChanged: (onSort) => sortDirection.value = onSort,
          orderBy: orderBy.value,
          onOrderByChanged: (onOrder) => orderBy.value = onOrder,
          hideRead: hideRead.value,
          onHideReadChanged: (onHideRead) => hideRead.value = onHideRead,
          downloadedOnly: downloadedOnly.value,
          onDownloadedOnlyChanged: (value) => downloadedOnly.value = value,
        ),
        series: query,
      ),
    );
  }
}
