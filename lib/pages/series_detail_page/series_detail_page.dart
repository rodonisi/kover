import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/menu_page/app_list_tile.dart';
import 'package:kover/pages/series_detail_page/pill_run.dart';
import 'package:kover/pages/series_detail_page/series_app_bar.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/extensions/iterable.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/details/summary.dart';
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
    final summary = ref.watch(
      seriesMetadataProvider(seriesId: seriesId).select(
        (value) => value.asData?.value.summary,
      ),
    );

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
                                AppListTile(
                                  title:
                                      '${l.specials} (${detailsData.specials.length})',
                                  onTap: () =>
                                      SpecialsRoute(seriesId: seriesId).push(
                                        context,
                                      ),
                                ),
                              if (detailsData.storyline.isNotEmpty)
                                AppListTile(
                                  title:
                                      '${l.storyline} (${detailsData.storyline.length})',
                                  onTap: () => StorylineRoute(
                                    seriesId: seriesId,
                                  ).push(context),
                                ),
                              if (detailsData.volumes.isNotEmpty)
                                AppListTile(
                                  title:
                                      '${l.volumes} (${detailsData.volumes.length})',
                                  onTap: () =>
                                      VolumesRoute(seriesId: seriesId)
                                          .push(context),
                                ),
                              if (detailsData.chapters.isNotEmpty)
                                AppListTile(
                                  title:
                                      '${l.chapters} (${detailsData.chapters.length})',
                                  onTap: () =>
                                      ChaptersRoute(seriesId: seriesId)
                                          .push(context),
                                ),
                              // Summary(summary: summary),
                              // _Genres(seriesId: seriesId),
                              // _Tags(seriesId: seriesId),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LayoutConstants.mediumPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Summary(
                            summary: summary,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LayoutConstants.mediumPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _Genres(seriesId: seriesId),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LayoutConstants.mediumPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _Tags(seriesId: seriesId),
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

class _Genres extends ConsumerWidget {
  final int seriesId;
  const _Genres({
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final metadata = ref.watch(seriesMetadataProvider(seriesId: seriesId));

    return Async(
      asyncValue: metadata,
      data: (metadata) {
        if (metadata.genres.isEmpty) return const SizedBox.shrink();
        return PillRun(
          title: l.genres,
          items: metadata.genres.map((g) => g.name).toList(),
        );
      },
    );
  }
}

class _Tags extends ConsumerWidget {
  final int seriesId;

  const new({required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final metadata = ref.watch(seriesMetadataProvider(seriesId: seriesId));
    return Async(
      asyncValue: metadata,
      data: (metadata) {
        if (metadata.tags.isEmpty) return const SizedBox.shrink();

        return PillRun(
          title: l.tags,
          items: metadata.tags.map((g) => g.name).toList(),
        );
      },
    );
  }
}
