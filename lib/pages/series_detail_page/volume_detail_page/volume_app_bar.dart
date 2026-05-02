import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/details/detail_app_bar.dart';
import 'package:kover/widgets/details/info_widgets.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VolumeAppBar extends ConsumerWidget {
  final int volumeId;

  const VolumeAppBar({
    super.key,
    required this.volumeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider(volumeId: volumeId));
    final progress = ref.watch(volumeProgressProvider(volumeId: volumeId));
    final downloadProgress =
        ref.watch(volumeDownloadProgressProvider(volumeId: volumeId)).value ??
        0.0;

    return AsyncSliver(
      asyncValue: volume,
      data: (data) => DetailAppBar(
        title: data.name,
        progress: progress.value,
        cover: VolumeCoverImage(
          volumeId: data.id,
          usePlaceholder: false,
        ),
        info: _VolumeInfo(volume: data),
        primaryColor: data.primaryColor,
        secondaryColor: data.secondaryColor,
        collapsedContinueButton: _VolumeTitleContinueButton(
          seriesId: data.seriesId,
          volumeId: data.id,
        ),
        expandedContinueButton: _VolumeContinuePointButton(
          seriesId: data.seriesId,
          volumeId: data.id,
        ),
        actions: [
          ActionsMenuButton(
            onMarkRead: () async {
              await ref
                  .read(
                    markVolumeReadProvider(
                      volumeId: data.id,
                    ).notifier,
                  )
                  .markRead();
            },
            onMarkUnread: () async {
              await ref
                  .read(
                    markVolumeReadProvider(
                      volumeId: data.id,
                    ).notifier,
                  )
                  .markUnread();
            },
            onDownload: downloadProgress < 1.0
                ? () async {
                    await ref
                        .read(downloadManagerProvider.notifier)
                        .enqueueVolume(data.id);
                  }
                : null,
            onRemoveDownload: downloadProgress > 0.0
                ? () async {
                    await ref
                        .read(downloadManagerProvider.notifier)
                        .deleteVolume(data.id);
                  }
                : null,
            child: const Icon(LucideIcons.ellipsisVertical),
          ),
        ],
      ),
    );
  }
}

class _VolumeContinueButtonImage extends ConsumerWidget {
  final int volumeId;
  const _VolumeContinueButtonImage({required this.volumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      volumeContinuePointProvider(volumeId: volumeId),
    );

    return Async(
      asyncValue: continuePoint,
      data: (data) => ContinueButtonImage(
        image: ChapterCoverImage(
          chapterId: data.id,
          usePlaceholder: false,
        ),
      ),
    );
  }
}

class _VolumeTitleContinueButton extends ConsumerWidget {
  final int seriesId;
  final int volumeId;

  const _VolumeTitleContinueButton({
    required this.seriesId,
    required this.volumeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      volumeContinuePointProvider(volumeId: volumeId),
    );

    return Async(
      asyncValue: continuePoint,
      data: (data) => TitleContinueButton(
        child: _VolumeContinueButtonImage(volumeId: volumeId),
        onTap: () =>
            ReaderRoute(seriesId: seriesId, chapterId: data.id).push(context),
      ),
    );
  }
}

class _VolumeContinuePointButton extends ConsumerWidget {
  final int seriesId;
  final int volumeId;

  const _VolumeContinuePointButton({
    required this.seriesId,
    required this.volumeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      volumeContinuePointProvider(volumeId: volumeId),
    );

    return Async(
      asyncValue: continuePoint,
      data: (data) => ContinuePointButton(
        title: data.title,
        cover: _VolumeContinueButtonImage(volumeId: volumeId),
        progress: ref.watch(chapterProgressProvider(chapterId: data.id)).value,
        onTap: () =>
            ReaderRoute(seriesId: seriesId, chapterId: data.id).push(context),
      ),
    );
  }
}

class _VolumeInfo extends ConsumerWidget {
  final VolumeModel volume;

  const _VolumeInfo({required this.volume});

  Null get seriesId => null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: .start,
      spacing: LayoutConstants.largePadding,
      children: [
        Wrap(
          spacing: LayoutConstants.mediumPadding,
          runSpacing: LayoutConstants.mediumPadding,
          alignment: .spaceBetween,
          children: [
            if ((volume.wordCount ?? 0) > 0)
              WordCount(wordCount: volume.wordCount!),
            Pages(pages: volume.pages),
            RemainingHours(
              hours: volume.avgHoursToRead ?? 0,
            ),
          ],
        ),
      ],
    );
  }
}
