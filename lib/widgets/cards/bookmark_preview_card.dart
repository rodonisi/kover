import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/riverpod/repository/bookmark_repository.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

/// A square preview of a bookmark's page image, used in carousels and the
/// chapter bookmark gallery.
class BookmarkPreviewCard extends ConsumerWidget {
  final BookmarkModel bookmark;
  final VoidCallback? onTap;
  final bool showGoToChapter;
  final bool showGoToVolume;
  final bool showGoToSeries;

  const new({
    super.key,
    required this.bookmark,
    this.onTap,
    this.showGoToChapter = true,
    this.showGoToVolume = true,
    this.showGoToSeries = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final image = ref.watch(bookmarkImageProvider(bookmark));
    final canRead =
        ref.watch(canReadChapterProvider(bookmark.chapterId)).value ?? false;
    final hasVolume = ref.watch(
      volumesProvider(seriesId: bookmark.seriesId).select(
        (volumes) =>
            volumes.value?.any((volume) => volume.id == bookmark.volumeId) ??
            false,
      ),
    );

    return ContextMenuRegion(
      contextMenu: ContextMenu(
        entries: <ContextMenuEntry>[
          MenuItem(
            label: Text(l.removeBookmark),
            icon: const Icon(KoverIcons.bookmarkOff),
            onSelected: (_) {
              ref
                  .read(bookmarkRepositoryProvider)
                  .removeBookmark(
                    chapterId: bookmark.chapterId,
                    page: bookmark.page,
                    imageOffset: bookmark.imageOffset,
                    xPath: bookmark.xPath,
                  );
            },
          ),
          const MenuDivider(),
          if (showGoToChapter)
            MenuItem(
              label: Text(l.goToChapter),
              icon: const Icon(KoverIcons.chapter),
              onSelected: (_) {
                ChapterDetailRoute(
                  seriesId: bookmark.seriesId,
                  chapterId: bookmark.chapterId,
                ).push(context);
              },
            ),
          if (hasVolume && showGoToVolume)
            MenuItem(
              label: Text(l.goToVolume),
              icon: const Icon(KoverIcons.volume),
              onSelected: (_) {
                VolumeDetailRoute(
                  seriesId: bookmark.seriesId,
                  volumeId: bookmark.volumeId,
                ).push(context);
              },
            ),
          if (showGoToSeries)
            MenuItem(
              label: Text(l.goToSeries),
              icon: const Icon(KoverIcons.series),
              onSelected: (_) {
                SeriesDetailRoute(seriesId: bookmark.seriesId).push(context);
              },
            ),
        ],
      ),
      child: Card(
        clipBehavior: .antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Async(
                asyncValue: image,
                loading: () => const LoadingCover(),
                error: (error, stacktrace) {
                  log.error(
                    'failed to load bookmark image',
                    error: error,
                    stacktrace: stacktrace,
                  );
                  return const _BookmarkPlaceholder();
                },
                data: (data) => Image.memory(
                  data.data,
                  fit: .cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canRead ? onTap : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkPlaceholder extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const Card.filled(
      margin: EdgeInsets.zero,
      child: Center(
        child: Icon(KoverIcons.coverPlaceholder),
      ),
    );
  }
}
