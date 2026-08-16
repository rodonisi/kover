import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/pages/series_detail_page/series_app_bar_provider.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/details/detail_app_bar.dart';
import 'package:kover/widgets/details/info_widgets.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

class SeriesAppBar extends HookConsumerWidget {
  final int seriesId;
  final PreferredSizeWidget? bottom;

  const SeriesAppBar({
    super.key,
    required this.seriesId,
    this.bottom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesProvider(seriesId: seriesId));
    final downloadProgress =
        ref.watch(seriesDownloadProgressProvider(seriesId: seriesId)).value ??
        0.0;
    final progress = ref.watch(seriesProgressProvider(seriesId: seriesId));

    return AsyncSliver(
      asyncValue: series,
      data: (data) {
        return DetailAppBar(
          title: data.name,
          progress: progress.value,
          actions: [
            WantToReadToggle(seriesId: data.id),
            ActionsMenuButton(
              onMarkRead: () async {
                await ref
                    .read(
                      markSeriesReadProvider(
                        seriesId: seriesId,
                      ).notifier,
                    )
                    .markRead();
              },
              onMarkUnread: () async {
                await ref
                    .read(
                      markSeriesReadProvider(
                        seriesId: seriesId,
                      ).notifier,
                    )
                    .markUnread();
              },
              onDownload: downloadProgress < 1.0
                  ? () async {
                      await ref
                          .read(downloadManagerProvider.notifier)
                          .enqueueSeries(seriesId);
                    }
                  : null,
              onRemoveDownload: downloadProgress > 0.0
                  ? () async {
                      await ref
                          .read(downloadManagerProvider.notifier)
                          .deleteSeries(seriesId);
                    }
                  : null,
              onRefreshMetadata: () {
                ref
                    .read(syncManagerProvider.notifier)
                    .refreshMetadataAndDetails(seriesId: seriesId);
              },
              onRefreshCovers: () {
                ref
                    .read(syncManagerProvider.notifier)
                    .refreshCovers(seriesId: seriesId);
              },
              child: const Icon(LucideIcons.ellipsisVertical),
            ),
          ],
          primaryColor: data.primaryColor,
          secondaryColor: data.secondaryColor,
          cover: SeriesCoverImage(
            seriesId: seriesId,
            usePlaceholder: false,
          ),
          info: _Metadata(series: data),
          collapsedContinueButton: _SeriesTitleContinueButton(
            seriesId: seriesId,
          ),
          expandedContinueButton: _SeriesContinuePointButton(
            seriesId: seriesId,
          ),
        );
      },
    );
  }
}

class _SeriesContinueButtonImage extends ConsumerWidget {
  final int seriesId;
  const _SeriesContinueButtonImage({required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      seriesAppBarContinueButtonProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: state,
      data: (data) => ContinueButtonImage(
        enabled: data.canRead,
        image: ChapterCoverImage(
          chapterId: data.chapter.id,
          usePlaceholder: false,
        ),
      ),
    );
  }
}

class _SeriesTitleContinueButton extends ConsumerWidget {
  final int seriesId;

  const _SeriesTitleContinueButton({
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = ref.watch(canReadSeriesProvider(seriesId)).value ?? false;

    return TitleContinueButton(
      onTap: canRead
          ? () => ReaderRoute(seriesId: seriesId).push(context)
          : null,
      child: _SeriesContinueButtonImage(seriesId: seriesId),
    );
  }
}

class _SeriesContinuePointButton extends ConsumerWidget {
  final int seriesId;

  const _SeriesContinuePointButton({required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      seriesAppBarContinueButtonProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: state,
      data: (data) => ContinuePointButton(
        enabled: data.canRead,
        title: data.chapter.title,
        cover: _SeriesContinueButtonImage(seriesId: seriesId),
        progress: data.progress,
        onTap: () => ReaderRoute(seriesId: seriesId).push(context),
      ),
    );
  }
}

class _Metadata extends ConsumerWidget {
  final SeriesModel series;
  const _Metadata({
    required this.series,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final metadata = ref.watch(seriesMetadataProvider(seriesId: series.id));
    return Async(
      asyncValue: metadata,
      data: (metadata) => Column(
        crossAxisAlignment: .start,
        spacing: LayoutConstants.largePadding,
        children: [
          Wrap(
            spacing: LayoutConstants.mediumPadding,
            runSpacing: LayoutConstants.mediumPadding,
            children: [
              if ((series.wordCount ?? 0) > 0)
                WordCount(wordCount: series.wordCount!),
              Pages(pages: series.pages),
              RemainingHours(
                hours: series.avgHoursToRead,
              ),
              if (metadata.releaseYear != null)
                ReleaseYear(
                  releaseYear: metadata.releaseYear!,
                ),
              if (metadata.publicationStatus != .unknown)
                PublicationStatusDisplay(status: metadata.publicationStatus),
            ],
          ),
          Wrap(
            spacing: LayoutConstants.mediumPadding,
            runSpacing: LayoutConstants.mediumPadding,
            children: [
              if (metadata.writers.isNotEmpty)
                LimitedList(
                  title: l.writers,
                  items: metadata.writers
                      .map(
                        (w) => Text(
                          w.name,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
