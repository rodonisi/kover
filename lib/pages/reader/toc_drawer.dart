import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';

class TocDrawer extends ConsumerWidget {
  final int chapterId;
  final int seriesId;
  const TocDrawer({
    super.key,
    required this.chapterId,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref
        .watch(bookChaptersProvider(chapterId: chapterId))
        .whenData((chapters) {
          return chapters.map<Widget>((chapter) {
            return Card.filled(
              clipBehavior: .hardEdge,
              margin: EdgeInsets.zero,
              child: TocEntry(
                seriesId: seriesId,
                chapterId: chapterId,
                chapter: chapter,
              ),
            );
          }).toList();
        });

    return Drawer(
      child: Async(
        asyncValue: entries,
        data: (entries) {
          return SingleChildScrollView(
            child: Padding(
              padding: LayoutConstants.mediumEdgeInsets,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: LayoutConstants.smallPadding,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Table of Contents',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ...entries,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TocEntry extends ConsumerWidget {
  final int chapterId;
  final int seriesId;
  final BookChapterModel chapter;
  final int depth;
  const TocEntry({
    super.key,
    required this.chapterId,
    required this.seriesId,
    required this.chapter,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(
      readerNavigationProvider(seriesId: seriesId, chapterId: chapterId),
    );
    final key = GlobalKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.currentPage == chapter.page && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return Column(
      mainAxisSize: .min,
      children: [
        ListTile(
          key: key,
          selected: nav.currentPage == chapter.page,
          contentPadding: depth > 0
              ? EdgeInsetsGeometry.only(
                  left: depth * LayoutConstants.largePadding,
                  right: LayoutConstants.mediumPadding,
                )
              : null,
          title: Text(chapter.title),
          onTap: () {
            ref
                .read(
                  readerNavigationProvider(
                    chapterId: chapterId,
                    seriesId: seriesId,
                  ).notifier,
                )
                .jumpToPage(chapter.page);
          },
        ),
        ...chapter.children.map<Widget>(
          (child) => TocEntry(
            chapterId: chapterId,
            seriesId: seriesId,
            chapter: child,
            depth: depth + 1,
          ),
        ),
      ],
    );
  }
}
