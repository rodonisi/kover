import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures.dart';
import 'package:kover/pages/reader/overlay/reader_shortcuts.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/riverpod/repository/bookmark_repository.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

/// A full-screen viewer for the bookmarks in a series, volume or chapter.
/// Displays one bookmark image at a time and allows swiping, tapping, or
/// keybinds to navigate between them, independent of the reader.
class BookmarkViewerPage extends ConsumerWidget {
  final int seriesId;
  final int? volumeId;
  final int? chapterId;
  final int initialIndex;

  const BookmarkViewerPage({
    super.key,
    required this.seriesId,
    this.volumeId,
    this.chapterId,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(
      bookmarksProvider(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      ),
    );

    final readable = ref.watch(
      readableBookmarksProvider(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      ),
    );

    final reduceAnimations = ref.watch(
      themeProvider.select(
        (value) =>
            value.whenOrNull(data: (data) => data.reduceAnimations) ??
            const ThemeModel().reduceAnimations,
      ),
    );

    return Async(
      asyncValue: all,
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      data: (items) {
        if (readable.isEmpty) {
          return const _ViewerEmpty();
        }

        final tapped = initialIndex < items.length ? items[initialIndex] : null;
        final initial = tapped == null
            ? 0
            : readable.indexOf(tapped).clamp(0, readable.length - 1);

        return _ViewerBody(
          seriesId: seriesId,
          bookmarks: readable,
          initialIndex: initial,
          reduceAnimations: reduceAnimations,
        );
      },
    );
  }
}

class _ViewerBody extends HookConsumerWidget {
  final int seriesId;
  final List<BookmarkModel> bookmarks;
  final int initialIndex;
  final bool reduceAnimations;

  const _ViewerBody({
    required this.seriesId,
    required this.bookmarks,
    required this.initialIndex,
    required this.reduceAnimations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = bookmarks;
    final controller = usePageController(initialPage: initialIndex);
    final current = useState(initialIndex);
    final zoomedIndexes = useState(<int>{});
    final pointerCount = useState(0);
    final uiVisible = useState(false);

    final overlayFadeDuration = reduceAnimations
        ? Duration.zero
        : const Duration(milliseconds: 100);

    int currentIndex() => controller.hasClients
        ? (controller.page?.round() ?? current.value)
        : current.value;

    void goTo(int index) {
      if (!controller.hasClients) return;
      final target = index.clamp(0, items.length - 1);
      if (reduceAnimations) {
        controller.jumpToPage(target);
      } else {
        controller.animateToPage(
          target,
          duration: LayoutConstants.pageSlideDuration,
          curve: Curves.easeInOut,
        );
      }
    }

    void removeCurrentBookmark() {
      final index = currentIndex();
      if (index < 0 || index >= items.length) return;
      final bookmark = items[index];
      ref
          .read(bookmarkRepositoryProvider)
          .removeBookmark(
            chapterId: bookmark.chapterId,
            page: bookmark.page,
            imageOffset: bookmark.imageOffset,
            xPath: bookmark.xPath,
          );
    }

    useEffect(() {
      if (items.isEmpty || current.value < items.length) return null;
      final last = items.length - 1;
      current.value = last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) controller.jumpToPage(last);
      });
      return null;
    }, [items.length]);

    final physics =
        zoomedIndexes.value.contains(current.value) || pointerCount.value >= 2
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    final position =
        '${current.value.clamp(0, items.length - 1) + 1} / ${items.length}';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: IgnorePointer(
          ignoring: !uiVisible.value,
          child:
              AppBar(
                    actionsPadding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.mediumPadding,
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(KoverIcons.bookmarkOn),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: l.removeBookmark,
                        onPressed: removeCurrentBookmark,
                      ),
                      Center(child: Text(position)),
                    ],
                  )
                  .animate(
                    target: uiVisible.value ? 1.0 : 0.0,
                  )
                  .fade(
                    duration: overlayFadeDuration,
                    curve: Curves.easeInOut,
                  ),
        ),
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
        },
        child: ReaderShortcuts(
          onNextPage: () => goTo(currentIndex() + 1),
          onPreviousPage: () => goTo(currentIndex() - 1),
          child: Stack(
            children: [
              Listener(
                onPointerDown: (_) => pointerCount.value++,
                onPointerUp: (_) =>
                    pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
                onPointerCancel: (_) =>
                    pointerCount.value = (pointerCount.value - 1).clamp(0, 10),
                child: PageView.builder(
                  controller: controller,
                  allowImplicitScrolling: true,
                  pageSnapping: true,
                  itemCount: items.length,
                  physics: physics,
                  onPageChanged: (index) => current.value = index,
                  itemBuilder: (context, index) {
                    final bookmark = items[index];
                    return Async(
                      asyncValue: ref.watch(bookmarkImageProvider(bookmark)),
                      data: (image) => ZoomableHorizontalPageImage(
                        key: ValueKey(bookmark.id),
                        outerController: controller,
                        onZoomChanged: (zoomed) {
                          final next = {...zoomedIndexes.value};
                          zoomed ? next.add(index) : next.remove(index);
                          zoomedIndexes.value = next;
                        },
                        child: Image.memory(
                          image.data,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: OverlayGestures(
                  seriesId: seriesId,
                  disableGestures: pointerCount.value >= 2,
                  onLeftTap: () => goTo(currentIndex() - 1),
                  onRightTap: () => goTo(currentIndex() + 1),
                  onCenterTap: () => uiVisible.value = !uiVisible.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerEmpty extends StatelessWidget {
  const _ViewerEmpty();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(),
      body: Center(
        child: Text(
          l.noBookmarks,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
