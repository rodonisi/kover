import 'package:material_ui/material_ui.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/widgets/cards/reading_list_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';

class ReadingListsSliverGrid extends StatelessWidget {
  final List<ReadingListModel> readingLists;
  final int? rowCount;
  final void Function(int crossAxisCount)? onCrossAxisCountChanged;

  const ReadingListsSliverGrid({
    super.key,
    required this.readingLists,
    this.rowCount,
    this.onCrossAxisCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverGrid(
      itemCount: readingLists.length,
      rowCount: rowCount,
      onCrossAxisCountChanged: onCrossAxisCountChanged,
      builder: (context, index) {
        final readingList = readingLists[index];
        return ReadingListCard(
          key: ValueKey(readingList.id),
          readingListId: readingList.id,
        );
      },
    );
  }
}
