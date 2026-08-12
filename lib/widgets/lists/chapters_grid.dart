import 'package:material_ui/material_ui.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/widgets/cards/chapter_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';

class ChaptersGrid extends StatelessWidget {
  final int seriesId;
  final List<ChapterModel> chapters;

  const ChaptersGrid({
    super.key,
    required this.seriesId,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverGrid(
      itemCount: chapters.length,
      builder: (context, index) {
        final chapter = chapters[index];
        return ChapterCard(
          key: ValueKey(chapter.id),
          chapterId: chapter.id,
          seriesId: seriesId,
        );
      },
    );
  }
}
