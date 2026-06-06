import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/riverpod/providers/router.dart';
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
    final progress = ref.watch(
      readingListProgressProvider(readingListId: readingListId),
    );

    return AsyncSliver(
      asyncValue: readingList,
      data: (readingList) {
        return DetailAppBar(
          title: readingList.title,
          primaryColor: readingList.primaryColor,
          secondaryColor: readingList.secondaryColor,
          progress: progress.value,
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
                    '$count ${count == 1 ? 'item' : 'items'}',
                  ),
                ),
            ],
          ),
          collapsedContinueButton: _ReadingListTitleContinueButton(
            readingListId: readingListId,
          ),
          expandedContinueButton: _ReadingListContinuePointButton(
            readingListId: readingListId,
          ),
        );
      },
    );
  }
}

class _ReadingListContinueButtonImage extends ConsumerWidget {
  final int readingListId;
  const _ReadingListContinueButtonImage({required this.readingListId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      readingListContinuePointProvider(readingListId: readingListId),
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

class _ReadingListContinuePointButton extends ConsumerWidget {
  final int readingListId;

  const _ReadingListContinuePointButton({required this.readingListId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      readingListContinuePointProvider(readingListId: readingListId),
    );
    final progress = ref.watch(
      readingListContinuePointProgressProvider(readingListId: readingListId),
    );

    return Async(
      asyncValue: continuePoint,
      data: (data) => ContinuePointButton(
        title: data.title,
        cover: _ReadingListContinueButtonImage(readingListId: readingListId),
        progress: progress.value,
        onTap: () => ReaderRoute(
          seriesId: data.seriesId,
          chapterId: data.id,
          readingListId: readingListId,
        ).push(context),
      ),
    );
  }
}

class _ReadingListTitleContinueButton extends ConsumerWidget {
  final int readingListId;

  const _ReadingListTitleContinueButton({
    required this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuePoint = ref.watch(
      readingListContinuePointProvider(readingListId: readingListId),
    );
    return Async(
      asyncValue: continuePoint,
      data: (data) => TitleContinueButton(
        child: _ReadingListContinueButtonImage(readingListId: readingListId),
        onTap: () => ReaderRoute(
          seriesId: data.seriesId,
          chapterId: data.id,
          readingListId: readingListId,
        ).push(context),
      ),
    );
  }
}
