import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/bookmark_preview_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

/// A gallery of every bookmark in a series, volume or chapter, shown as a grid
/// of square previews. The app bar title reflects the current scope.
class BookmarksGridPage extends ConsumerWidget {
  final int seriesId;
  final int? volumeId;
  final int? chapterId;

  const BookmarksGridPage({
    super.key,
    required this.seriesId,
    this.volumeId,
    this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bookmarks = ref.watch(
      bookmarksProvider(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      ),
    );

    final String title = switch ((chapterId, volumeId)) {
      (final int id, _) =>
        ref.watch(chapterProvider(chapterId: id)).value?.title ?? l.bookmarks,
      (_, final int id) =>
        ref.watch(volumeProvider(volumeId: id)).value?.name ?? l.bookmarks,
      _ =>
        ref.watch(seriesProvider(seriesId: seriesId)).value?.name ??
            l.bookmarks,
    };

    void openViewer(int index) {
      switch ((chapterId, volumeId)) {
        case (final int id, _):
          ChapterBookmarkViewerRoute(
            seriesId: seriesId,
            chapterId: id,
            index: index,
          ).push(context);
        case (_, final int id):
          VolumeBookmarkViewerRoute(
            seriesId: seriesId,
            volumeId: id,
            index: index,
          ).push(context);
        default:
          SeriesBookmarkViewerRoute(
            seriesId: seriesId,
            index: index,
          ).push(context);
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(title)),
          SliverSafeArea(
            top: false,
            bottom: false,
            sliver: AsyncSliver(
              asyncValue: bookmarks,
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(l.noBookmarks)),
                  );
                }

                return SliverPadding(
                  padding: LayoutConstants.smallEdgeInsets,
                  sliver: AdaptiveSliverGrid(
                    itemCount: items.length,
                    childAspectRatio: LayoutConstants.bookmarkCardAspectRatio,
                    builder: (context, index) => BookmarkPreviewCard(
                      bookmark: items[index],
                      onTap: () => openViewer(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
