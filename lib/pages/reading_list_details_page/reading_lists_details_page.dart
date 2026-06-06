import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reading_list_details_page/reading_list_app_bar.dart';
import 'package:kover/pages/reading_list_details_page/reading_list_chapter_entry.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/utils/layout_constants.dart';
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
