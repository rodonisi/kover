import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/menu_page/app_list_tile.dart';
import 'package:kover/pages/menu_page/sliver_libraries.dart';
import 'package:kover/pages/menu_page/sliver_section.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/actions_app_bar/actions_app_bar.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider.notifier).syncLibraries();
    });

    final loggedIn = ref.watch(
      currentUserProvider.select((state) => state.hasValue),
    );

    final isDownloading = ref.watch(
      downloadManagerProvider.select(
        (state) => state.value?.downloadQueue.isNotEmpty ?? false,
      ),
    );

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            if (loggedIn) ...[
              const ActionsAppBar(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  vertical: LayoutConstants.smallerPadding,
                  horizontal: LayoutConstants.mediumPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: AppListTile(
                    title: l.allSeries,
                    icon: const Icon(LucideIcons.list),
                    onTap: () => const AllSeriesRoute().push(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  vertical: LayoutConstants.smallerPadding,
                  horizontal: LayoutConstants.mediumPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: AppListTile(
                    title: l.collections,
                    icon: const Icon(KoverIcons.collection),
                    onTap: () => const CollectionsRoute().push(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  vertical: LayoutConstants.smallerPadding,
                  horizontal: LayoutConstants.mediumPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: AppListTile(
                    title: l.readingLists,
                    icon: const Icon(KoverIcons.readingList),
                    onTap: () => const ReadingListsRoute().push(context),
                  ),
                ),
              ),
              SliverSection(title: l.libraries),
              const SliverLibraries(),
            ],
            SliverSection(title: l.downloadQueue),
            SliverPadding(
              padding: const EdgeInsetsGeometry.symmetric(
                vertical: LayoutConstants.smallerPadding,
                horizontal: LayoutConstants.mediumPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: AppListTile(
                  title: l.downloadQueue,
                  icon: isDownloading
                      ? const Icon(LucideIcons.refreshCw)
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .rotate(duration: 1500.ms)
                      : const Icon(LucideIcons.download),
                  onTap: () => const DownloadQueueRoute().push(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsGeometry.symmetric(
                vertical: LayoutConstants.smallerPadding,
                horizontal: LayoutConstants.mediumPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: AppListTile(
                  title: l.settings,
                  icon: const Icon(LucideIcons.settings),
                  onTap: () => const SettingsRoute().push(context),
                ),
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
