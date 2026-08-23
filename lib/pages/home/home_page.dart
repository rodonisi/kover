import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/dashboard_section_model.dart';
import 'package:kover/pages/home/sliver_on_deck.dart';
import 'package:kover/pages/home/sliver_recently_added.dart';
import 'package:kover/pages/home/sliver_recently_updated.dart';
import 'package:kover/pages/home/sliver_smart_filter_section.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/dashboard.dart';
import 'package:kover/widgets/actions_app_bar/actions_app_bar.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBody: true,
      body: LoginGuard(child: HomePageContent()),
    );
  }
}

class HomePageContent extends ConsumerWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(dashboardSectionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncManagerProvider.notifier).fullSync();
      },
      child: CustomScrollView(
        clipBehavior: .none,
        slivers: [
          const ActionsAppBar(),
          SliverSafeArea(
            top: false,
            bottom: false,
            sliver: AsyncSliver(
              asyncValue: sections,
              data: (data) {
                if (data.isEmpty) {
                  // Fall back to the default sections until the first dashboard sync
                  // has populated the database.
                  return const SliverMainAxisGroup(
                    slivers: [
                      SliverOnDeck(),
                      SliverRecentlyUpdated(),
                      SliverRecentlyAdded(),
                    ],
                  );
                }

                return SliverMainAxisGroup(
                  slivers: data
                      .map(
                        (section) => section.when(
                          onDeck: () => const SliverOnDeck(),
                          recentlyUpdated: () => const SliverRecentlyUpdated(),
                          newlyAdded: () => const SliverRecentlyAdded(),
                          smartFilter: (int id) =>
                              SliverSmartFilterSection(smartFilterId: id),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
