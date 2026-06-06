import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/pages/reading_list_details_page/reading_list_app_bar.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/lists/cover_list_entry.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class ReadingListsDetailsPage extends ConsumerWidget {
  final int readingListId;

  const ReadingListsDetailsPage({super.key, required this.readingListId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingList = ref.watch(
      readingListProvider(readingListId: readingListId),
    );
    final chapters = ref.watch(
      readingListChaptersProvider(readingListId: readingListId),
    );

    return Scaffold(
      body: Async(
        asyncValue: readingList,
        data: (detailsData) {
          return CustomScrollView(
            slivers: [
              ReadingListAppBar(readingListId: readingListId),
              SliverPadding(
                padding: const EdgeInsetsGeometry.only(
                  top: LayoutConstants.mediumPadding,
                  left: LayoutConstants.mediumPadding,
                  right: LayoutConstants.mediumPadding,
                ),
                sliver: AsyncSliver(
                  asyncValue: chapters,
                  data: (chapters) {
                    return SliverList.separated(
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        return ReadingListChapterEntry(
                          readingListId: readingListId,
                          chapter: chapter,
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(
                        height: LayoutConstants.mediumPadding,
                      ),
                      itemCount: chapters.length,
                    );
                  },
                ),
              ),
              const SliverBottomPadding(),
            ],
          );
        },
        loading: () => CustomScrollView(
          slivers: [
            ReadingListAppBar(readingListId: readingListId),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class ReadingListChapterEntry extends ConsumerWidget {
  final int readingListId;
  final ChapterModel chapter;
  const ReadingListChapterEntry({
    super.key,
    required this.readingListId,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesProvider(seriesId: chapter.seriesId));
    final progress = ref.watch(
      chapterProgressProvider(chapterId: chapter.id),
    );
    return Async(
      asyncValue: series,
      data: (series) {
        return ContextMenuRegion(
          contextMenu: ContextMenu(
            entries: [
              MenuItem(
                label: Text('Go to chapter'),
                icon: const Icon(KoverIcons.chapter),
                onSelected: (_) {
                  ChapterDetailRoute(
                    seriesId: chapter.seriesId,
                    chapterId: chapter.id,
                  ).push(context);
                },
              ),
              MenuItem(
                label: const Text('Go to series'),
                icon: const Icon(KoverIcons.series),
                onSelected: (_) {
                  SeriesDetailRoute(seriesId: series.id).push(context);
                },
              ),
            ],
          ),
          child: CoverListEntry(
            margin: EdgeInsets.zero,
            title: chapter.title,
            subtitle: series.name,
            cover: ChapterCoverImage(chapterId: chapter.id),
            progress: progress.value,
            trailing: const Icon(
              KoverIcons.chevronRight,
            ),
            onTap: () {
              ReaderRoute(
                seriesId: chapter.seriesId,
                chapterId: chapter.id,
                readingListId: readingListId,
              ).push(context);
            },
          ),
        );
      },
    );
  }
}
