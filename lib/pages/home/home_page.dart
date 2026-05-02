import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/home/collapsible_section.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/widgets/actions_app_bar/actions_app_bar.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/login_guard.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncManagerProvider.notifier).fullSync();
          },
          child: const CustomScrollView(
            slivers: [
              ActionsAppBar(),
              OnDeck(),
              RecentlyUpdated(),
              RecentlyAdded(),
              SliverBottomPadding(),
            ],
          ),
        ),
      ),
    );
  }
}

class OnDeck extends ConsumerWidget {
  const OnDeck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDeck = ref.watch(onDeckProvider);

    return AsyncSliver(
      asyncValue: onDeck,
      data: (data) => CollapsibleSection(title: 'On Deck', series: data),
    );
  }
}

class RecentlyUpdated extends ConsumerWidget {
  const RecentlyUpdated({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(recentlyUpdatedProvider);

    return AsyncSliver(
      asyncValue: series,
      data: (data) =>
          CollapsibleSection(title: 'Recently Updated', series: data),
    );
  }
}

class RecentlyAdded extends ConsumerWidget {
  const RecentlyAdded({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(recentlyAddedProvider);

    return AsyncSliver(
      asyncValue: series,
      data: (data) => CollapsibleSection(title: 'Recently Added', series: data),
    );
  }
}
