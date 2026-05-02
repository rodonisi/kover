import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/lists/cover_list_entry.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DownloadQueuePage extends ConsumerWidget {
  const DownloadQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDls = ref.watch(
      downloadManagerProvider.select(
        (state) => state.value?.downloadQueue.isNotEmpty ?? false,
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        physics: hasDls ? null : const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('Download Queue'),
            actions: [
              if (hasDls) const CancellAllAction(),
            ],
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.mediumPadding,
            ),
            sliver: DownloadQueueList(),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}

class CancellAllAction extends ConsumerWidget {
  const CancellAllAction({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        await ref.read(downloadManagerProvider.notifier).cancelAll();
      },
      child: const Text('Cancel All'),
    );
  }
}

class DownloadQueueList extends ConsumerWidget {
  const DownloadQueueList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref.watch(downloadManagerProvider);
    return AsyncSliver(
      asyncValue: queued,
      data: (data) {
        if (data.downloadQueue.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('No downloads in queue')),
          );
        }
        final queued = data.downloadQueue.toList();
        return SliverList.builder(
          itemCount: queued.length,
          itemBuilder: (context, index) {
            return DownloadQueueItem(chapterId: queued[index]);
          },
        );
      },
    );
  }
}

class DownloadQueueItem extends ConsumerWidget {
  final int chapterId;

  const DownloadQueueItem({
    super.key,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(chapterProvider(chapterId: chapterId));
    final series = ref.watch(seriesForChapterProvider(chapterId: chapterId));

    final progress = ref.watch(
      chapterDownloadProgressProvider(chapterId: chapterId),
    );

    return Async(
      asyncValue: chapter,
      data: (data) {
        return CoverListEntry(
          cover: ChapterCoverImage(chapterId: chapterId),
          title: data.title,
          subtitle: series.value?.name,
          progress: progress.value,
          trailing: IconButton(
            onPressed: () async {
              await ref
                  .read(downloadManagerProvider.notifier)
                  .cancel(chapterId);
            },
            icon: const Icon(LucideIcons.x),
          ),
        );
      },
    );
  }
}
