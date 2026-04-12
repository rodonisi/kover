import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/series_detail_page/chapter_detail_page/chapter_app_bar.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/sliver_bottom_padding.dart';
import 'package:kover/widgets/summary.dart';

class ChapterDetailPage extends ConsumerWidget {
  final int chapterId;

  const ChapterDetailPage({
    super.key,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(chapterProvider(chapterId: chapterId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ChapterAppBar(
            chapterId: chapterId,
          ),
          SliverPadding(
            padding: const EdgeInsets.only(
              top: LayoutConstants.mediumPadding,
              right: LayoutConstants.mediumPadding,
              left: LayoutConstants.mediumPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Async(
                    asyncValue: chapter,
                    data: (chapter) => Summary(
                      summary: chapter.summary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
