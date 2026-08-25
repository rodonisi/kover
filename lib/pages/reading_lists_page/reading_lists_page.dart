import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reading_lists_page/reading_lists_list_page.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:material_ui/material_ui.dart';

class ReadingListsPage extends StatelessWidget {
  const ReadingListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(child: ReadingListsPageContent()),
    );
  }
}

class ReadingListsPageContent extends HookConsumerWidget {
  const ReadingListsPageContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final readingLists = ref.watch(readingListsProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider.notifier).syncReadingLists();
    });

    return ReadingListsListPage(
      title: l.readingLists,
      readingLists: readingLists,
    );
  }
}
