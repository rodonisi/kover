import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/download_status_icon.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/util/async_value.dart';

class ChapterCard extends HookConsumerWidget {
  const ChapterCard({
    super.key,
    required this.chapterId,
    required this.seriesId,
  });

  final int chapterId;
  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(chapterProvider(chapterId: chapterId));
    final progress = ref
        .watch(chapterProgressProvider(chapterId: chapterId))
        .value;

    final markReadProvider = markChapterReadProvider(chapterId: chapterId);

    final isDownloaded =
        ref.watch(chapterDownloadedProvider(chapterId: chapterId)).value ??
        false;

    final canRead = ref.watch(canReadChapterProvider(chapterId)).value ?? false;

    final downloadProgress = ref
        .watch(chapterDownloadProgressProvider(chapterId: chapterId))
        .value;

    return Async(
      asyncValue: chapter,
      data: (chapter) => ActionsContextMenu(
        onMarkRead: () async {
          await ref.read(markReadProvider.notifier).markRead();
        },
        onMarkUnread: () async {
          await ref.read(markReadProvider.notifier).markUnread();
        },
        onDownload: !isDownloaded
            ? () async {
                await ref
                    .read(downloadManagerProvider.notifier)
                    .enqueue(chapterId);
              }
            : null,
        onRemoveDownload: isDownloaded
            ? () async {
                await ref
                    .read(downloadManagerProvider.notifier)
                    .deleteChapter(chapterId);
              }
            : null,
        child: CoverCard(
          title: chapter.title,
          coverImage: ChapterCoverImage(chapterId: chapterId),
          progress: progress,
          downloadStatusIcon: DownloadStatusIcon(
            progress: downloadProgress,
          ),
          onTap: () => ChapterDetailRoute(
            seriesId: seriesId,
            chapterId: chapterId,
          ).push(context),
          onActionTap: () {
            ReaderRoute(
              seriesId: seriesId,
              chapterId: chapterId,
            ).push(context);
          },
          actionDisabled: !canRead,
        ),
      ),
    );
  }
}
