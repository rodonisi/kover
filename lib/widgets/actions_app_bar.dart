import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/cover_image.dart';
import 'package:kover/widgets/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String _phaseLabel(SyncPhase phase) {
  return phase.when(
    allSeries: () => 'Syncing all series',
    seriesDetails: () => 'Syncing series details',
    metadata: () => 'Syncing metadata',
    recentlyAdded: () => 'Syncing recently added',
    recentlyUpdated: () => 'Syncing recently updated',
    libraries: () => 'Syncing libraries',
    progress: () => 'Syncing progress',
    covers: () => 'Syncing covers',
    refreshCovers: (seriesId) => 'Refreshing covers for series $seriesId',
  );
}

class ActionsAppBar extends StatelessWidget {
  const ActionsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // return Row(
    //   children: [
    //     Padding(
    //       padding: EdgeInsets.symmetric(
    //         horizontal: LayoutConstants.smallPadding,
    //       ),
    //       child: _ActionsBar(),
    //     ),
    //   ],
    // );
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      forceMaterialTransparency: true,
      elevation: 0,
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
            SearchButton(),
            _SyncButton(),
          ],
        ),
      ),
    );
  }
}

class SearchButton extends HookConsumerWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useSearchController();

    return SearchAnchor(
      searchController: controller,
      isFullScreen: true,
      headerHeight: 40.0, // Reduced from 56.0
      headerTextStyle: Theme.of(context).textTheme.bodyLarge,
      viewLeading: IconButton(
        style: IconButton.styleFrom(visualDensity: .compact),
        icon: Icon(
          LucideIcons.chevronLeft,
          size: LayoutConstants.mediumIcon,
        ),
        onPressed: () => controller.closeView(null),
      ),
      viewTrailing: [
        IconButton(
          style: IconButton.styleFrom(visualDensity: .compact),
          icon: const Icon(
            LucideIcons.x,
            size: LayoutConstants.mediumIcon,
          ), // Shrink trailing icon
          onPressed: () => controller.clear(),
        ),
      ],
      builder: (BuildContext context, SearchController controller) {
        return IconButton(
          style: IconButton.styleFrom(visualDensity: .compact),
          icon: const Icon(LucideIcons.search, size: LayoutConstants.smallIcon),
          onPressed: () {
            controller.openView(); // Manually opens the search view
          },
        );
      },
      suggestionsBuilder: (context, controller) async {
        final theme = Theme.of(context);
        final seriesResults = await ref.read(
          searchSeriesProvider(controller.text).future,
        );
        final volumesResults = await ref.watch(
          searchVolumesProvider(controller.text).future,
        );
        final chaptersResults = await ref.watch(
          searchChaptersProvider(controller.text).future,
        );

        if (seriesResults.isEmpty &&
            volumesResults.isEmpty &&
            chaptersResults.isEmpty)
          return [];

        return [
          if (seriesResults.isNotEmpty) ...[
            Text(
              'Series',
              style: theme.textTheme.headlineSmall,
            ),
            ...seriesResults.map(
              (series) => SearchSeriesEntry(
                series: series,
                controller: controller,
              ),
            ),
          ],
          if (volumesResults.isNotEmpty) ...[
            Text(
              'Volumes',
              style: theme.textTheme.headlineSmall,
            ),
            ...volumesResults.map(
              (volume) => SearchVolumeEntry(
                volume: volume,
                controller: controller,
              ),
            ),
          ],
          if (chaptersResults.isNotEmpty) ...[
            Text(
              'Chapters',
              style: theme.textTheme.headlineSmall,
            ),
            ...chaptersResults.map(
              (chapter) => SearchChapterEntry(
                chapter: chapter,
                controller: controller,
              ),
            ),
          ],
          ListBottomPadding(),
        ].map(
          (entry) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.mediumPadding,
              vertical: LayoutConstants.smallerPadding,
            ),
            child: entry,
          ),
        );
      },
    );
  }
}

class SearchSeriesEntry extends ConsumerWidget {
  final SeriesModel series;
  final SearchController controller;

  const SearchSeriesEntry({
    super.key,
    required this.series,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(seriesProgressProvider(seriesId: series.id));
    final libraryName = ref.watch(
      libraryProvider(
        libraryId: series.libraryId,
      ).select((state) => state.value?.name),
    );

    return CoverListEntry(
      title: series.name,
      subtitle: libraryName,
      cover: SeriesCoverImage(seriesId: series.id),
      progress: progress.value,
      trailing: Icon(LucideIcons.chevronRight),
      margin: EdgeInsets.zero,
      onTap: () {
        controller.closeView(null);
        SeriesDetailRoute(seriesId: series.id).go(context);
      },
    );
  }
}

class SearchVolumeEntry extends ConsumerWidget {
  final VolumeModel volume;
  final SearchController controller;

  const SearchVolumeEntry({
    super.key,
    required this.volume,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(volumeProgressProvider(volumeId: volume.id));
    final seriesName = ref.watch(
      seriesProvider(
        seriesId: volume.seriesId,
      ).select((state) => state.value?.name),
    );

    return CoverListEntry(
      title: volume.name,
      subtitle: seriesName,
      cover: VolumeCoverImage(
        volumeId: volume.id,
      ),
      progress: progress.value,
      trailing: Icon(LucideIcons.chevronRight),
      margin: EdgeInsets.zero,
      onTap: () {
        controller.closeView(null);
        VolumeDetailRoute(
          seriesId: volume.seriesId,
          volumeId: volume.id,
        ).go(context);
      },
    );
  }
}

class SearchChapterEntry extends ConsumerWidget {
  final ChapterModel chapter;
  final SearchController controller;

  const SearchChapterEntry({
    super.key,
    required this.chapter,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(chapterProgressProvider(chapterId: chapter.id));
    final seriesName = ref.watch(
      seriesProvider(
        seriesId: chapter.seriesId,
      ).select((state) => state.value?.name),
    );
    final volumeName = ref.watch(
      volumeProvider(
        volumeId: chapter.volumeId,
      ).select((state) => state.value?.name),
    );
    final list = [seriesName, volumeName].whereType<String>();
    final subtitle = list.isEmpty ? '' : list.join(' - ');

    return CoverListEntry(
      title: chapter.title,
      subtitle: subtitle,
      cover: ChapterCoverImage(chapterId: chapter.id),
      progress: progress.value,
      trailing: Icon(LucideIcons.chevronRight),
      margin: EdgeInsets.zero,
      onTap: () {
        controller.closeView(null);
        ChapterDetailRoute(
          seriesId: chapter.seriesId,
          chapterId: chapter.id,
        ).go(context);
      },
    );
  }
}

class CoverListEntry extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget? cover;
  final Widget? trailing;
  final double? progress;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const CoverListEntry({
    super.key,
    required this.title,
    this.subtitle,
    this.cover,
    this.trailing,
    this.progress,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card.filled(
      clipBehavior: .hardEdge,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: LayoutConstants.smallEdgeInsets,
          child: Row(
            spacing: LayoutConstants.mediumPadding,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  LayoutConstants.smallPadding,
                ),
                child: SizedBox(
                  height: LayoutConstants.largestIcon,
                  child: cover,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: .start,
                  spacing: LayoutConstants.smallPadding,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: .ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: .ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: LayoutConstants.mediumIcon,
                child: CircularProgressIndicator(
                  value: progress,
                ),
              ),
              Icon(LucideIcons.chevronRight),
            ],
          ),
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
