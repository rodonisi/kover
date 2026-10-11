import 'package:kover/utils/constants/kover_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/download_status_icon.dart';
import 'package:kover/widgets/cards/series_card_provider.dart';
import 'package:kover/widgets/context_menu/series_actions_menu.dart';
import 'package:kover/widgets/util/async_value.dart';

class SeriesCard extends HookConsumerWidget {
  final int seriesId;

  /// Overrides the default navigation to the series detail page.
  final VoidCallback? onTap;

  /// Hides the read action button.
  final bool hideAction;

  /// When set, adds a "Series details" entry to the context menu.
  final VoidCallback? onViewDetails;

  const SeriesCard({
    super.key,
    required this.seriesId,
    this.onTap,
    this.hideAction = false,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(seriesCardProvider(seriesId: seriesId));
    final progress = ref
        .watch(seriesProgressProvider(seriesId: seriesId))
        .value;

    final downloadStatus = ref.watch(
      seriesDownloadStatusProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: model,
      data: (data) => SeriesActionsContextMenu(
        seriesId: seriesId,
        onViewDetails: onViewDetails,
        child: CoverCard(
          title: data.series.name,
          icon: Icon(
            switch (data.series.format) {
              .epub => KoverIcons.epubFormat,
              .archive => KoverIcons.archiveFormat,
              .image => KoverIcons.imageFormat,
              .pdf => KoverIcons.pdfFormat,
              _ => KoverIcons.unknownFormat,
            },
            size: LayoutConstants.smallIcon,
          ),
          progress: progress,
          coverImage: SeriesCoverImage(seriesId: seriesId),
          downloadStatusIcon: DownloadStatusIcon(status: downloadStatus.value),
          onTap:
              onTap ??
              () {
                SeriesDetailRoute(seriesId: seriesId).push(context);
              },
          onActionTap: hideAction
              ? null
              : () {
                  ReaderRoute(
                    seriesId: seriesId,
                    chapterId: data.continuePoint.id,
                    readingListId: null,
                  ).push(context);
                },
          actionDisabled: !data.canRead,
        ),
      ),
    );
  }
}
