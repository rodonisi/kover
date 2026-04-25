import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/download_status_icon.dart';

class VolumeCard extends HookConsumerWidget {
  const VolumeCard({
    super.key,
    required this.volumeId,
  });

  final int volumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider(volumeId: volumeId));
    final progress = ref
        .watch(volumeProgressProvider(volumeId: volumeId))
        .value;

    final markReadProvider = markVolumeReadProvider(
      volumeId: volumeId,
    );

    final downloadProgress =
        ref.watch(volumeDownloadProgressProvider(volumeId: volumeId)).value ??
        0.0;

    final continuePoint = ref.watch(
      volumeContinuePointProvider(volumeId: volumeId),
    );

    return Async(
      asyncValue: volume,
      data: (volume) => Async(
        asyncValue: continuePoint,
        data: (continuePoint) => ActionsContextMenu(
          onMarkRead: () async {
            await ref.read(markReadProvider.notifier).markRead();
          },
          onMarkUnread: () async {
            await ref.read(markReadProvider.notifier).markUnread();
          },
          onDownload: downloadProgress < 1.0
              ? () async {
                  await ref
                      .read(downloadManagerProvider.notifier)
                      .enqueueVolume(volumeId);
                }
              : null,
          onRemoveDownload: downloadProgress > 0.0
              ? () async {
                  await ref
                      .read(downloadManagerProvider.notifier)
                      .deleteVolume(volumeId);
                }
              : null,
          child: CoverCard(
            title: volume.name,
            coverImage: VolumeCoverImage(volumeId: volume.id),
            progress: progress,
            downloadStatusIcon: DownloadStatusIcon(
              progress: downloadProgress,
            ),
            actionDisabled:
                !(ref
                        .watch(
                          canReadChapterProvider(continuePoint.id),
                        )
                        .value ??
                    false),
            onActionTap: volume.chapters.isEmpty
                ? null
                : () {
                    ReaderRoute(
                      seriesId: volume.seriesId,
                      chapterId: continuePoint.id,
                    ).push(context);
                  },
            onTap: () {
              VolumeDetailRoute(
                seriesId: volume.seriesId,
                volumeId: volume.id,
              ).push(context);
            },
          ),
        ),
      ),
    );
  }
}
