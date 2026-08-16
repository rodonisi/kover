import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/carousel_tile.dart';
import 'package:kover/pages/series_detail_page/series_app_bar.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/extensions/iterable.dart';
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
    final l = AppLocalizations.of(context);
    final details = ref.watch(seriesDetailProvider(seriesId: seriesId));

    return Scaffold(
      body: Async(
        asyncValue: details,
        data: (detailsData) {
          return CustomScrollView(
            slivers:
                [
                      SeriesAppBar(seriesId: seriesId),
                      SliverPadding(
                        padding: const EdgeInsetsGeometry.only(
                          top: LayoutConstants.mediumPadding,
                          left: LayoutConstants.mediumPadding,
                          right: LayoutConstants.mediumPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            spacing: LayoutConstants.smallPadding,
                            crossAxisAlignment: .start,
                            children: [
                              if (detailsData.specials.isNotEmpty)
                                CarouselTile(
                                  title:
                                      '${l.specials} (${detailsData.specials.length})',
                                  onTap: () => SpecialsRoute(
                                    seriesId: seriesId,
                                  ).push(context),
                                  listItemCount: detailsData.specials.length,
                                  listItemBuilder: (context, index) {
                                    final special = detailsData.specials[index];
                                    return AspectRatio(
                                      aspectRatio: LayoutConstants
                                          .chapterCardAspectRatio,
                                      child: ChapterCard(
                                        seriesId: seriesId,
                                        chapterId: special.id,
                                      ),
                                    );
                                  },
                                ),
                              if (detailsData.storyline.isNotEmpty)
                                CarouselTile(
                                  title:
                                      '${l.storyline} (${detailsData.storyline.length})',
                                  onTap: () => StorylineRoute(
                                    seriesId: seriesId,
                                  ).push(context),
                                  listItemCount: detailsData.storyline.length,
                                  listItemBuilder: (context, index) {
                                    final storyline =
                                        detailsData.storyline[index];
                                    return AspectRatio(
                                      aspectRatio: LayoutConstants
                                          .chapterCardAspectRatio,
                                      child: ChapterCard(
                                        seriesId: seriesId,
                                        chapterId: storyline.id,
                                      ),
                                    );
                                  },
                                ),
                              if (detailsData.volumes.isNotEmpty)
                                CarouselTile(
                                  title:
                                      '${l.volumes} (${detailsData.volumes.length})',
                                  onTap: () => VolumesRoute(
                                    seriesId: seriesId,
                                  ).push(context),
                                  listItemCount: detailsData.volumes.length,
                                  listItemBuilder: (context, index) {
                                    final volume = detailsData.volumes[index];
                                    return AspectRatio(
                                      aspectRatio: LayoutConstants
                                          .chapterCardAspectRatio,
                                      child: VolumeCard(
                                        volumeId: volume.id,
                                      ),
                                    );
                                  },
                                ),
                              if (detailsData.chapters.isNotEmpty)
                                CarouselTile(
                                  title:
                                      '${l.chapters} (${detailsData.chapters.length})',
                                  onTap: () => ChaptersRoute(
                                    seriesId: seriesId,
                                  ).push(context),
                                  listItemCount: detailsData.chapters.length,
                                  listItemBuilder: (context, index) {
                                    final chapter = detailsData.chapters[index];
                                    return AspectRatio(
                                      aspectRatio: LayoutConstants
                                          .chapterCardAspectRatio,
                                      child: ChapterCard(
                                        seriesId: seriesId,
                                        chapterId: chapter.id,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LayoutConstants.mediumPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: MetadataSections(
                            asyncValue: ref.watch(
                              seriesMetadataProvider(seriesId: seriesId),
                            ),
                          ),
                        ),
                      ),
                      const SliverBottomPadding(),
                    ]
                    .interleave(
                      const SliverToBoxAdapter(
                        child: SizedBox(height: LayoutConstants.mediumPadding),
                      ),
                    )
                    .toList(),
          );
        },
        loading: () => CustomScrollView(
          slivers: [
            SeriesAppBar(
              seriesId: seriesId,
            ),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
