import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';

class EpubTocDrawer extends HookConsumerWidget {
  final int chapterId;
  final int seriesId;
  const EpubTocDrawer({
    super.key,
    required this.chapterId,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selectedKey = useState<GlobalKey?>(null);
    final hasScrolled = useState(false);

    useEffect(() {
      ref
          .read(syncManagerProvider.notifier)
          .refreshChapterToc(chapterId: chapterId);
      return null;
    }, []);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (selectedKey.value?.currentContext != null && !hasScrolled.value) {
        await Scrollable.ensureVisible(
          selectedKey.value!.currentContext!,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        hasScrolled.value = true;
      }
    });

    final entries = ref
        .watch(bookChaptersProvider(chapterId: chapterId))
        .whenData((chapters) {
          return chapters.map<Widget>((chapter) {
            return TocEntry(
              seriesId: seriesId,
              chapterId: chapterId,
              chapter: chapter,
              onSelected: (key) {
                selectedKey.value = key;
              },
            );
          }).toList();
        });

    return Drawer(
      child: Async(
        asyncValue: entries,
        data: (entries) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.mediumPadding,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: LayoutConstants.smallPadding,
                  crossAxisAlignment: .start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LayoutConstants.mediumPadding,
                      ),
                      child: Text(
                        l.tableOfContents,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    ...entries,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TocEntry extends HookConsumerWidget {
  final int chapterId;
  final int seriesId;
  final BookChapterModel chapter;
  final int depth;
  final void Function(GlobalKey) onSelected;
  const TocEntry({
    super.key,
    required this.chapterId,
    required this.seriesId,
    required this.chapter,
    required this.onSelected,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = useMemoized(() => GlobalKey(), []);
    final nav = ref.watch(
      readerNavigationProvider(seriesId: seriesId, chapterId: chapterId),
    );

    return Async(
      asyncValue: nav,
      data: (nav) {
        final isSelected = nav.currentPage == chapter.page;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isSelected) {
            onSelected(key);
          }
        });

        return Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              key: key,
              selected: isSelected,
              contentPadding: depth > 0
                  ? EdgeInsetsGeometry.only(
                      left: depth * LayoutConstants.mediumPadding,
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
                onSelected: onSelected,
              ),
            ),
          ],
        );
      },
    );
  }
}
