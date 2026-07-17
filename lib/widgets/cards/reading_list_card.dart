import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/util/async_value.dart';

class ReadingListCard extends ConsumerWidget {
  final int readingListId;

  const ReadingListCard({
    super.key,
    required this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(
      readingListProvider(readingListId: readingListId),
    );
    final continuePoint = ref.watch(
      readingListContinuePointProvider(readingListId: readingListId),
    );
    final canRead = ref.watch(canReadReadingListProvider(readingListId));

    return Async3(
      asyncValue1: collection,
      asyncValue2: continuePoint,
      asyncValue3: canRead,
      data: (collection, continuePoint, canRead) => CoverCard(
        title: collection.title,
        icon: const Icon(
          KoverIcons.readingList,
          size: LayoutConstants.smallIcon,
        ),
        coverImage: ReadingListCoverImage(readingListId: readingListId),
        actionDisabled: !canRead,
        onActionTap: () {
          ReaderRoute(
            seriesId: continuePoint.seriesId,
            chapterId: continuePoint.id,
            readingListId: readingListId,
          );
        },
        onTap: () {
          ReadingListDetailsRoute(readingListId: readingListId).push(context);
        },
      ),
    );
  }
}
