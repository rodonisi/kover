import 'package:flutter/material.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/widgets/adaptive_sliver_grid.dart';
import 'package:kover/widgets/chapter_card.dart';

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
        return ChapterCard(chapterId: chapter.id, seriesId: seriesId);
      },
    );
  }
}
