import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SyncButton extends HookConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncManagerProvider);
    final isIdle = syncState is IdleState;

    final overlayController = useOverlayPortalController();
    final layerLink = useMemoized(LayerLink.new);

    // Close the overlay when transitioning back to idle.
    ref.listen(syncManagerProvider, (_, next) {
      if (next is IdleState && overlayController.isShowing) {
        overlayController.hide();
      }
    });

    final icon = syncState.when(
      idle: () =>
          const Icon(LucideIcons.refreshCw, size: LayoutConstants.smallIcon),
      syncing: (_) => const Icon(
        LucideIcons.refreshCw,
        size: LayoutConstants.smallIcon,
      ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1500.ms),
      error: (_, _) => Icon(
        LucideIcons.circleAlert,
        size: LayoutConstants.smallIcon,
        color: Theme.of(context).colorScheme.error,
      ),
    );

    return OverlayPortal(
      controller: overlayController,
      overlayChildBuilder: (_) => CompositedTransformFollower(
        link: layerLink,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(
          LayoutConstants.smallPadding,
          LayoutConstants.smallPadding,
        ),
        child: const Align(
          alignment: Alignment.topRight,
          child: SyncMenuOverlay(),
        ),
      ),
      child: CompositedTransformTarget(
        link: layerLink,
        child: TapRegion(
          onTapOutside: (_) {
            if (overlayController.isShowing) overlayController.hide();
          },
          child: InkWell(
            onTap: isIdle
                ? () => ref.read(syncManagerProvider.notifier).fullSync()
                : () {
                    if (overlayController.isShowing) {
                      overlayController.hide();
                    } else {
                      overlayController.show();
                    }
                  },
            customBorder: const CircleBorder(),
            child: Padding(
              padding: LayoutConstants.smallEdgeInsets,
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

class SyncMenuOverlay extends ConsumerWidget {
  const SyncMenuOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final syncState = ref.watch(syncManagerProvider);

    final entries =
        syncState.whenOrNull(
          syncing: (phases) => [
            for (final phase in phases)
              (
                label: _phaseLabel(l, phase),
              ),
          ],
        ) ??
        [];

    return Card(
      margin: EdgeInsets.zero,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.smallPadding,
                  vertical: LayoutConstants.smallPadding,
                ),
                child: Text(
                  l.noActiveSyncOperations,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.smallPadding,
                  vertical: LayoutConstants.smallPadding,
                ),
                child: Row(
                  spacing: LayoutConstants.smallPadding,
                  children: [
                    const SizedBox.square(
                      dimension: LayoutConstants.smallerIcon,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                    Text(
                      entry.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _phaseLabel(AppLocalizations l, SyncPhase phase) {
  return phase.when(
    allSeries: () => l.syncingAllSeries,
    metadata: () => l.syncingMetadata,
    tocs: () => l.syncingTocs,
    recentlyAdded: () => l.syncingRecentlyAdded,
    recentlyUpdated: () => l.syncingRecentlyUpdated,
    libraries: () => l.syncingLibraries,
    progress: () => l.syncingProgress,
    covers: () => l.syncingCovers,
    collections: () => l.syncingCollections,
    readingLists: () => l.syncingReadingLists,
    refreshMetadata: (seriesId) => l.refreshingMetadataForSeries(seriesId),
    refreshCovers: (seriesId) => l.refreshingCoversForSeries(seriesId),
    refreshServerSettings: () => l.refreshingServerSettings,
    refreshToc: (chapterId) => l.refreshingChapterToc(chapterId),
  );
}
