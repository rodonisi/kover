import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/series_detail_page/volume_detail_page/volume_app_bar.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/chapters_grid.dart';
import 'package:kover/widgets/sliver_bottom_padding.dart';
import 'package:kover/widgets/summary.dart';

class VolumeDetailPage extends ConsumerWidget {
  final int volumeId;

  const VolumeDetailPage({
    super.key,
    required this.volumeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider(volumeId: volumeId)).value;

    if (volume == null) return const SizedBox.shrink();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          VolumeAppBar(
            volumeId: volumeId,
          ),
          if (volume.chapters.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                top: LayoutConstants.mediumPadding,
                right: LayoutConstants.mediumPadding,
                left: LayoutConstants.mediumPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Summary(
                      summary: volume.chapters.first.summary,
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsetsGeometry.symmetric(
              horizontal: LayoutConstants.mediumPadding,
              vertical: LayoutConstants.smallPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Chapters',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.mediumPadding,
            ),
            sliver: ChaptersGrid(
              seriesId: volume.seriesId,
              chapters: volume.chapters,
            ),
          ),

          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
