import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/cards/reading_list_card_provider.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class ReadingListCard extends ConsumerWidget {
  final int readingListId;

  const ReadingListCard({
    super.key,
    required this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(
      readingListCardProvider(readingListId: readingListId),
    );

    return Async(
      asyncValue: model,
      data: (data) => CoverCard(
        title: data.readingList.title,
        icon: const Icon(
          KoverIcons.readingList,
          size: LayoutConstants.smallIcon,
        ),
        coverImage: ReadingListCoverImage(readingListId: readingListId),
        actionDisabled: !data.canRead,
        onActionTap: () {
          ReaderRoute(
            seriesId: data.continuePoint.seriesId,
            chapterId: data.continuePoint.id,
            readingListId: readingListId,
          ).push(context);
        },
        onTap: () {
          ReadingListDetailsRoute(readingListId: readingListId).push(context);
        },
      ),
    );
  }
}
