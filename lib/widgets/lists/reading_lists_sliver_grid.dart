import 'package:flutter/material.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/widgets/cards/reading_list_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';

class ReadingListsSliverGrid extends StatelessWidget {
  final List<ReadingListModel> readingLists;

  const ReadingListsSliverGrid({
    super.key,
    required this.readingLists,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverGrid(
      itemCount: readingLists.length,
      builder: (context, index) {
        final readingList = readingLists[index];
        return ReadingListCard(readingListId: readingList.id);
      },
    );
  }
}
