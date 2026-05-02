import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/lists/cover_list_entry.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchButton extends HookConsumerWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useSearchController();

    return SearchAnchor(
      searchController: controller,
      isFullScreen: true,
      headerHeight: 45.0,
      headerTextStyle: Theme.of(context).textTheme.bodyLarge,
      viewLeading: IconButton(
        style: IconButton.styleFrom(visualDensity: .compact),
        icon: const Icon(
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
          ),
          onPressed: () => controller.clear(),
        ),
      ],
      builder: (BuildContext context, SearchController controller) {
        return IconButton(
          style: IconButton.styleFrom(visualDensity: .compact),
          icon: const Icon(
            LucideIcons.search,
            size: LayoutConstants.smallIcon,
          ),
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
            chaptersResults.isEmpty) {
          return [];
        }

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
          const ListBottomPadding(),
        ].map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(
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
      trailing: const Icon(LucideIcons.chevronRight),
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
      trailing: const Icon(LucideIcons.chevronRight),
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
      trailing: const Icon(LucideIcons.chevronRight),
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
