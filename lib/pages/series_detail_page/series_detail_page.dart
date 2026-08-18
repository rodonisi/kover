import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/carousel_tile.dart';
import 'package:kover/pages/series_detail_page/sliver_metadata_display.dart';
import 'package:kover/pages/series_detail_page/series_app_bar.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/chapter_card.dart';
import 'package:kover/widgets/cards/volume_card.dart';
import 'package:kover/widgets/details/metadata_sections.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

class SeriesDetailPage extends HookConsumerWidget {
  final int seriesId;

  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: MetadataScope(
        metadataId: .series(seriesId: seriesId),
        child: CustomScrollView(
          clipBehavior: .none,
          slivers: [
            SeriesAppBar(seriesId: seriesId),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverMetadataDisplay(
                sliverCarousels: SliverPadding(
                  padding: const .only(
                    top: LayoutConstants.mediumPadding,
                  ),
                  sliver: _SliverCarouselTiles(seriesId: seriesId),
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

class _SliverCarouselTiles extends ConsumerWidget {
  final int seriesId;

  const new({required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final details = ref.watch(seriesDetailProvider(seriesId: seriesId));

    return AsyncSliver(
      asyncValue: details,
      data: (detailsData) {
        return SliverToBoxAdapter(
          child: Column(
            children: [
              if (detailsData.specials.isNotEmpty)
                CarouselTile(
                  title: '${l.specials} (${detailsData.specials.length})',
                  onTap: () => SpecialsRoute(
                    seriesId: seriesId,
                  ).push(context),
                  listItemCount: detailsData.specials.length,
                  listItemBuilder: (context, index) {
                    final special = detailsData.specials[index];
                    return AspectRatio(
                      aspectRatio: LayoutConstants.chapterCardAspectRatio,
                      child: ChapterCard(
                        seriesId: seriesId,
                        chapterId: special.id,
                      ),
                    );
                  },
                ),
              if (detailsData.storyline.isNotEmpty)
                CarouselTile(
                  title: '${l.storyline} (${detailsData.storyline.length})',
                  onTap: () => StorylineRoute(
                    seriesId: seriesId,
                  ).push(context),
                  listItemCount: detailsData.storyline.length,
                  listItemBuilder: (context, index) {
                    final storyline = detailsData.storyline[index];
                    return AspectRatio(
                      aspectRatio: LayoutConstants.chapterCardAspectRatio,
                      child: ChapterCard(
                        seriesId: seriesId,
                        chapterId: storyline.id,
                      ),
                    );
                  },
                ),
              if (detailsData.volumes.isNotEmpty)
                CarouselTile(
                  title: '${l.volumes} (${detailsData.volumes.length})',
                  onTap: () => VolumesRoute(
                    seriesId: seriesId,
                  ).push(context),
                  listItemCount: detailsData.volumes.length,
                  listItemBuilder: (context, index) {
                    final volume = detailsData.volumes[index];
                    return AspectRatio(
                      aspectRatio: LayoutConstants.chapterCardAspectRatio,
                      child: VolumeCard(
                        volumeId: volume.id,
                      ),
                    );
                  },
                ),
              if (detailsData.chapters.isNotEmpty)
                CarouselTile(
                  title: '${l.chapters} (${detailsData.chapters.length})',
                  onTap: () => ChaptersRoute(
                    seriesId: seriesId,
                  ).push(context),
                  listItemCount: detailsData.chapters.length,
                  listItemBuilder: (context, index) {
                    final chapter = detailsData.chapters[index];
                    return AspectRatio(
                      aspectRatio: LayoutConstants.chapterCardAspectRatio,
                      child: ChapterCard(
                        seriesId: seriesId,
                        chapterId: chapter.id,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
