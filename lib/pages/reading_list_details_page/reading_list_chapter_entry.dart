import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/lists/cover_list_entry.dart';
import 'package:kover/widgets/util/async_value.dart';

class ReadingListChapterEntry extends ConsumerWidget {
  final int readingListId;
  final ChapterModel chapter;
  const ReadingListChapterEntry({
    super.key,
    required this.readingListId,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final series = ref.watch(seriesProvider(seriesId: chapter.seriesId));
    final progress = ref.watch(
      chapterProgressProvider(chapterId: chapter.id),
    );
    return Async(
      asyncValue: series,
      data: (series) {
        return ContextMenuRegion(
          contextMenu: ContextMenu(
            entries: [
              MenuItem(
                label: Text(l.goToChapter),
                icon: const Icon(KoverIcons.chapter),
                onSelected: (_) {
                  ChapterDetailRoute(
                    seriesId: chapter.seriesId,
                    chapterId: chapter.id,
                  ).push(context);
                },
              ),
              MenuItem(
                label: Text(l.goToSeries),
                icon: const Icon(KoverIcons.series),
                onSelected: (_) {
                  SeriesDetailRoute(seriesId: series.id).push(context);
                },
              ),
            ],
          ),
          child: CoverListEntry(
            margin: EdgeInsets.zero,
            title: chapter.title,
            subtitle: series.name,
            cover: ChapterCoverImage(chapterId: chapter.id),
            progress: progress.value,
            trailing: const Icon(
              KoverIcons.chevronRight,
            ),
            onTap: () {
              ReaderRoute(
                seriesId: chapter.seriesId,
                chapterId: chapter.id,
                readingListId: readingListId,
              ).push(context);
            },
          ),
        );
      },
    );
  }
}
