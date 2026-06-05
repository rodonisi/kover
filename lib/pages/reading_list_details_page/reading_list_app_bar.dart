import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/details/detail_app_bar.dart';
import 'package:kover/widgets/util/async_value.dart';

class ReadingListAppBar extends HookConsumerWidget {
  final int readingListId;
  final PreferredSizeWidget? bottom;

  const ReadingListAppBar({
    super.key,
    required this.readingListId,
    this.bottom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingList = ref.watch(
      readingListProvider(readingListId: readingListId),
    );
    final chapterCount = ref.watch(
      readingListChaptersProvider(readingListId: readingListId).select(
        (value) => value.whenData((chapters) => chapters.length),
      ),
    );

    return AsyncSliver(
      asyncValue: readingList,
      data: (readingList) {
        return DetailAppBar(
          title: readingList.title,
          primaryColor: readingList.primaryColor,
          secondaryColor: readingList.secondaryColor,
          progress: 0,
          cover: ReadingListCoverImage(
            readingListId: readingListId,
            usePlaceholder: false,
          ),
          info: Column(
            crossAxisAlignment: .start,
            children: [
              if (readingList.summary != null)
                Async(
                  asyncValue: chapterCount,
                  data: (count) => Text(
                    '$count ${count == 1 ? 'entry' : 'entries'}',
                  ),
                ),
            ],
          ),
          collapsedContinueButton: const SizedBox.shrink(),
          expandedContinueButton: const SizedBox.shrink(),
        );
      },
    );
  }
}
