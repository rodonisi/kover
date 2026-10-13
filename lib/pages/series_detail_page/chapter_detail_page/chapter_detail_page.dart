import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/carousel_tile.dart';
import 'package:kover/pages/series_detail_page/chapter_detail_page/chapter_app_bar.dart';
import 'package:kover/pages/series_detail_page/sliver_metadata_display.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/bookmark_preview_card.dart';
import 'package:kover/widgets/details/metadata_sections.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

class ChapterDetailPage extends ConsumerWidget {
  final int seriesId;
  final int chapterId;

  const ChapterDetailPage({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: MetadataScope(
        metadataId: .chapter(chapterId: chapterId),
        child: CustomScrollView(
          slivers: [
            ChapterAppBar(
              chapterId: chapterId,
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverMetadataDisplay(
                sliverCarousels: SliverPadding(
                  padding: const .only(
                    top: LayoutConstants.mediumPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ChapterBookmarkCarousel(
                      seriesId: seriesId,
                      chapterId: chapterId,
                    ),
                  ),
                ),
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}

class _ChapterBookmarkCarousel extends ConsumerWidget {
  final int seriesId;
  final int chapterId;

  const _ChapterBookmarkCarousel({
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bookmarks =
        ref.watch(bookmarksProvider(chapterId: chapterId)).value ?? const [];

    if (bookmarks.isEmpty) return const SizedBox.shrink();

    return CarouselTile(
      title: '${l.bookmarks} (${bookmarks.length})',
      onTap: () => ChapterBookmarksRoute(
        seriesId: seriesId,
        chapterId: chapterId,
      ).push(context),
      listItemCount: bookmarks.length,
      listItemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return AspectRatio(
          aspectRatio: LayoutConstants.bookmarkCardAspectRatio,
          child: BookmarkPreviewCard(
            bookmark: bookmark,
            showGoToChapter: false,
            onTap: () => ChapterBookmarkViewerRoute(
              seriesId: seriesId,
              chapterId: chapterId,
              index: index,
            ).push(context),
          ),
        );
      },
    );
  }
}
