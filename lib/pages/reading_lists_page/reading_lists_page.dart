import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/order_by_option.dart';
import 'package:kover/models/enums/sort_direction.dart';
import 'package:kover/riverpod/managers/sync_manager/sync_manager.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/widgets/list_page/reading_lists_list_page.dart';
import 'package:kover/widgets/list_page/sort_options_menu.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class ReadingListsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(child: ReadingListsPageContent()),
    );
  }
}

class ReadingListsPageContent extends HookConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = useTextEditingController();
    final orderBy = useState(UnorderedSortOption.name);
    final sortDirection = useState(SortDirection.descending);
    final readingLists = ref.watch(
      readingListsProvider(
        query: controller.text,
        orderBy: orderBy.value,
        direction: sortDirection.value,
      ),
    );

    useListenable(controller);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(syncManagerProvider.notifier).syncReadingLists();
      });
      return null;
    }, const []);

    return ReadingListsListPage(
      title: l.readingLists,
      controller: controller,
      sortMenu: UnorderedSortMenu(
        sortDirection: sortDirection.value,
        onSortDirectionChanged: (SortDirection newDirection) {
          sortDirection.value = newDirection;
        },
        orderBy: orderBy.value,
        onOrderByChanged: (UnorderedSortOption newOrderBy) {
          orderBy.value = newOrderBy;
        },
      ),
      readingLists: readingLists,
    );
  }
}
