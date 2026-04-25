import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/details/detail_app_bar.dart';
import 'package:kover/widgets/details/info_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChapterAppBar extends ConsumerWidget {
  final int chapterId;

  const ChapterAppBar({
    super.key,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(chapterProvider(chapterId: chapterId));
    final progress = ref.watch(chapterProgressProvider(chapterId: chapterId));
    final downloadProgress =
        ref
            .watch(chapterDownloadProgressProvider(chapterId: chapterId))
            .value ??
        0.0;

    return AsyncSliver(
      asyncValue: chapter,
      data: (data) => DetailAppBar(
        title: data.title,
        progress: progress.value,
        cover: ChapterCoverImage(chapterId: data.id),
        info: _ChapterInfo(chapterId: chapterId),
        primaryColor: data.primaryColor,
        secondaryColor: data.secondaryColor,
        collapsedContinueButton: _ChapterTitleContinueButton(
          seriesId: data.seriesId,
          chapterId: data.id,
        ),
        expandedContinueButton: _ChapterContinuePointButton(
          seriesId: data.seriesId,
          chapterId: data.id,
        ),
        actions: [
          ActionsMenuButton(
            onMarkRead: () async {
              await ref
                  .read(
                    markChapterReadProvider(
                      chapterId: data.id,
                    ).notifier,
                  )
                  .markRead();
            },
            onMarkUnread: () async {
              await ref
                  .read(
                    markChapterReadProvider(
                      chapterId: data.id,
                    ).notifier,
                  )
                  .markUnread();
            },
            onDownload: downloadProgress < 1.0
                ? () async {
                    await ref
                        .read(downloadManagerProvider.notifier)
                        .enqueue(data.id);
                  }
                : null,
            onRemoveDownload: downloadProgress > 0.0
                ? () async {
                    await ref
                        .read(downloadManagerProvider.notifier)
                        .deleteChapter(data.id);
                  }
                : null,
            child: const Icon(LucideIcons.ellipsisVertical),
          ),
        ],
      ),
    );
  }
}

class _ChapterContinueButtonImage extends ConsumerWidget {
  final int chapterId;
  const _ChapterContinueButtonImage({required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContinueButtonImage(
      image: ChapterCoverImage(chapterId: chapterId),
    );
  }
}

class _ChapterTitleContinueButton extends ConsumerWidget {
  final int seriesId;
  final int chapterId;

  const _ChapterTitleContinueButton({
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TitleContinueButton(
      child: _ChapterContinueButtonImage(chapterId: chapterId),
      onTap: () =>
          ReaderRoute(seriesId: seriesId, chapterId: chapterId).push(context),
    );
  }
}

class _ChapterContinuePointButton extends ConsumerWidget {
  final int seriesId;
  final int chapterId;

  const _ChapterContinuePointButton({
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContinuePointButton(
      cover: _ChapterContinueButtonImage(chapterId: chapterId),
      onTap: () =>
          ReaderRoute(seriesId: seriesId, chapterId: chapterId).push(context),
    );
  }
}

class _ChapterInfo extends ConsumerWidget {
  final int chapterId;

  const _ChapterInfo({required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(chapterProvider(chapterId: chapterId));

    return Async(
      asyncValue: chapter,
      data: (data) => Column(
        crossAxisAlignment: .start,
        spacing: LayoutConstants.largePadding,
        children: [
          Wrap(
            spacing: LayoutConstants.mediumPadding,
            runSpacing: LayoutConstants.mediumPadding,
            alignment: .spaceBetween,
            children: [
              if ((data.wordCount ?? 0) > 0)
                WordCount(wordCount: data.wordCount!),
              Pages(pages: data.pages),
              RemainingHours(
                hours: data.avgHoursToRead ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
