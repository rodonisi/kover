import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/want_to_read.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/download_status_icon.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SeriesCard extends HookConsumerWidget {
  const SeriesCard({
    super.key,
    required this.seriesId,
  });

  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesProvider(seriesId: seriesId));
    final progress = ref
        .watch(seriesProgressProvider(seriesId: seriesId))
        .value;

    final canRead = ref.watch(canReadSeriesProvider(seriesId)).value ?? false;

    final wantToRead = wantToReadProvider(seriesId: seriesId);
    final isWantToRead = ref.watch(wantToRead).value ?? false;

    final markReadProvider = markSeriesReadProvider(seriesId: seriesId);

    final downloadProgress =
        ref.watch(seriesDownloadProgressProvider(seriesId: seriesId)).value ??
        0.0;

    return Async(
      asyncValue: series,
      data: (series) => ActionsContextMenu(
        onMarkRead: () async {
          await ref.read(markReadProvider.notifier).markRead();
        },
        onMarkUnread: () async {
          await ref.read(markReadProvider.notifier).markUnread();
        },
        onAddWantToRead: isWantToRead
            ? null
            : () async {
                await ref.read(wantToRead.notifier).add();
              },
        onRemoveWantToRead: isWantToRead
            ? () async {
                await ref.read(wantToRead.notifier).remove();
              }
            : null,
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
        child: CoverCard(
          title: series.name,
          icon: Icon(
            switch (series.format) {
              .epub => LucideIcons.bookText,
              .archive => LucideIcons.fileArchive,
              _ => LucideIcons.fileQuestionMark,
            },
            size: LayoutConstants.smallIcon,
          ),
          progress: progress,
          coverImage: SeriesCoverImage(seriesId: seriesId),
          downloadStatusIcon: DownloadStatusIcon(
            progress: downloadProgress,
          ),
          onTap: () {
            SeriesDetailRoute(
              seriesId: seriesId,
            ).push(context);
          },
          onActionTap: () {
            ReaderRoute(seriesId: seriesId).push(context);
          },
          actionDisabled: !canRead,
        ),
      ),
    );
  }
}
