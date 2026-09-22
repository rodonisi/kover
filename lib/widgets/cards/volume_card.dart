import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/download_status_icon.dart';
import 'package:kover/widgets/cards/volume_card_provider.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/util/async_value.dart';

class VolumeCard extends HookConsumerWidget {
  const VolumeCard({
    super.key,
    required this.volumeId,
  });

  final int volumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(volumeCardProvider(volumeId: volumeId));
    final progress = ref
        .watch(volumeProgressProvider(volumeId: volumeId))
        .value;

    final markReadProvider = markVolumeReadProvider(
      volumeId: volumeId,
    );

    final downloadProgress =
        ref.watch(volumeDownloadProgressProvider(volumeId: volumeId)).value ??
        0.0;

    return Async(
      asyncValue: model,
      data: (data) => ActionsContextMenu(
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
          title: data.volume.name,
          coverImage: VolumeCoverImage(volumeId: data.volume.id),
          progress: progress,
          downloadStatusIcon: DownloadStatusIcon(
            progress: downloadProgress,
          ),
          actionDisabled: !data.canRead,
          onActionTap: () {
            ReaderRoute(
              seriesId: data.volume.seriesId,
              chapterId: data.continuePoint.id,
              readingListId: null,
            ).push(context);
          },
          onTap: () {
            VolumeDetailRoute(
              seriesId: data.volume.seriesId,
              volumeId: data.volume.id,
            ).push(context);
          },
        ),
      ),
    );
  }
}
