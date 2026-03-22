import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String _phaseLabel(SyncPhase phase) => switch (phase) {
  SyncPhase.allSeries => 'Syncing series',
  SyncPhase.seriesDetails => 'Syncing series details',
  SyncPhase.metadata => 'Syncing metadata',
  SyncPhase.libraries => 'Syncing libraries',
  SyncPhase.recentlyAdded => 'Syncing recently added',
  SyncPhase.recentlyUpdated => 'Syncing recently updated',
  SyncPhase.progress => 'Syncing progress',
  SyncPhase.covers => 'Syncing covers',
  SyncPhase.none => 'Syncing',
};

class ActionsAppBar extends StatelessWidget {
  const ActionsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      actions: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.smallPadding,
          ),
          child: _ActionsBar(),
        ),
      ],
    );
  }
}

class _ActionsBar extends ConsumerWidget {
  const _ActionsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.all(
          Radius.circular(LayoutConstants.mediumPadding),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(LayoutConstants.smallerPadding),
        child: Row(
          spacing: LayoutConstants.smallPadding,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SyncButton(),
          ],
        ),
      ),
    );
  }
}

class _SyncButton extends HookConsumerWidget {
  const _SyncButton();

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

    final overlayPortal = OverlayPortal(
      controller: overlayController,
      overlayChildBuilder: (_) => CompositedTransformFollower(
        link: layerLink,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, LayoutConstants.smallerPadding),
        child: const Align(
          alignment: Alignment.topRight,
          child: _SyncMenuOverlay(),
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

    return overlayPortal;
  }
}

class _SyncMenuOverlay extends ConsumerWidget {
  const _SyncMenuOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncManagerProvider);

    final entries = syncState.whenOrNull(
      syncing: (phases) => [
        for (final phase in phases)
          (
            label: _phaseLabel(phase),
          ),
      ],
    );

    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
