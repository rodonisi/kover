import 'package:kover/utils/extensions/iterable.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/carousel_tile.dart';
import 'package:kover/pages/series_detail_page/volume_detail_page/volume_app_bar.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/chapter_card.dart';
import 'package:kover/widgets/details/metadata_sections.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class VolumeDetailPage extends ConsumerWidget {
  final int volumeId;

  const VolumeDetailPage({
    super.key,
    required this.volumeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final volume = ref.watch(volumeProvider(volumeId: volumeId)).value;

    if (volume == null) return const SizedBox.shrink();

    var items = [
      VolumeAppBar(
        volumeId: volumeId,
      ),
      if (volume.chapters.isNotEmpty)
        SliverPadding(
          padding: const .symmetric(
            horizontal: LayoutConstants.mediumPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: CarouselTile(
              title: '${l.chapters} (${volume.chapters.length})',
              onTap: () => ChaptersRoute(
                seriesId: volume.seriesId,
                volumeId: volume.id,
              ).push(context),
              listItemCount: volume.chapters.length,
              listItemBuilder: (context, index) {
                final chapter = volume.chapters[index];
                return AspectRatio(
                  aspectRatio: LayoutConstants.chapterCardAspectRatio,
                  child: ChapterCard(
                    seriesId: volume.seriesId,
                    chapterId: chapter.id,
                  ),
                );
              },
            ),
          ),
        ),
      if (volume.chapters.isNotEmpty)
        SliverPadding(
          padding: const .symmetric(
            horizontal: LayoutConstants.mediumPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: MetadataSections(
              asyncValue: ref.watch(
                chapterMetadataProvider(
                  chapterId: volume.chapters.first.id,
                ),
              ),
            ),
          ),
        ),
      const SliverBottomPadding(),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: items
            .interleave(
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: LayoutConstants.mediumPadding,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
