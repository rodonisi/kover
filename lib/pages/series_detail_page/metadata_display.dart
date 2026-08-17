import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/metadata.dart';
import 'package:kover/utils/extensions/iterable.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/details/metadata_sections.dart';
import 'package:kover/widgets/util/breakpoint_builder.dart';
import 'package:material_ui/material_ui.dart';

class MetadataDisplay extends ConsumerWidget {
  final Widget? carousels;

  const new({
    super.key,
    this.carousels,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(
      metadataProvider(metadataId: MetadataScope.of(context)),
    );
    final visibleSlivers =
        metadata.whenOrNull(
          data: (data) => [
            if (data.genres.isNotEmpty) const SliverGenres(),
            if (data.tags.isNotEmpty) const SliverTags(),
            if (data.writers.isNotEmpty) const SliverWriters(),
            if (data.coverArtists.isNotEmpty) const SliverCoverArtists(),
            if (data.publishers.isNotEmpty) const SliverPublishers(),
            if (data.characters.isNotEmpty) const SliverCharacters(),
            if (data.pencillers.isNotEmpty) const SliverPencillers(),
            if (data.inkers.isNotEmpty) const SliverInkers(),
            if (data.imprints.isNotEmpty) const SliverImprints(),
            if (data.colorists.isNotEmpty) const SliverColorists(),
            if (data.letterers.isNotEmpty) const SliverLetterers(),
            if (data.editors.isNotEmpty) const SliverEditors(),
            if (data.translators.isNotEmpty) const SliverTranslators(),
            if (data.teams.isNotEmpty) const SliverTeams(),
            if (data.locations.isNotEmpty) const SliverLocations(),
          ],
        ) ??
        [];

    return SliverAdaptivePadding(
      sliver: SliverBreakpointBuilder(
        compactBuilder: (context) {
          return [?carousels, const SliverSummary(), ...visibleSlivers];
        },
        largeBuilder: (context) {
          return [
            SliverConstrainedCrossAxis(
              maxExtent: LayoutBreakpoints.large,
              sliver: SliverCrossAxisGroup(
                slivers: [
                  const SliverSummary(),
                  ?carousels,
                ],
              ),
            ),
            ...visibleSlivers
                .chunked(2)
                .map(
                  (chunk) => SliverConstrainedCrossAxis(
                    maxExtent: LayoutBreakpoints.large,
                    sliver: SliverCrossAxisGroup(
                      slivers: chunk.toList(),
                    ),
                  ),
                ),
          ];
        },
      ),
    );
  }
}
