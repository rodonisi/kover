import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';
import 'package:kover/pages/reader/overlay/overlay_gestures.dart';
import 'package:kover/pages/reader/overlay/reader_shortcuts.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

/// A full-screen viewer for the bookmarks in a series, volume or chapter.
/// Displays one bookmark image at a time and allows swiping, tapping, or
/// keybinds to navigate between them, independent of the reader.
class BookmarkViewerPage extends HookConsumerWidget {
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
    final bookmarks = ref.watch(
      bookmarksProvider(
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

    final controller = usePageController(initialPage: initialIndex);
    final current = useState(initialIndex);
    final zoomedIndexes = useState(<int>{});
    final pointerCount = useState(0);
    final uiVisible = useState(true);

    final overlayFadeDuration = reduceAnimations
        ? Duration.zero
        : const Duration(milliseconds: 100);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Async(
        asyncValue: bookmarks,
        data: (items) {
          if (items.isEmpty) {
            return _ViewerEmpty(onClose: () => context.pop());
          }

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

          final physics =
              zoomedIndexes.value.contains(current.value) ||
                  pointerCount.value >= 2
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics();

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  context.pop(),
            },
            child: ReaderShortcuts(
              onNextPage: () => goTo(currentIndex() + 1),
              onPreviousPage: () => goTo(currentIndex() - 1),
              child: Stack(
                children: [
                  Listener(
                    onPointerDown: (_) => pointerCount.value++,
                    onPointerUp: (_) => pointerCount.value =
                        (pointerCount.value - 1).clamp(0, 10),
                    onPointerCancel: (_) => pointerCount.value =
                        (pointerCount.value - 1).clamp(0, 10),
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
                          asyncValue: ref.watch(
                            bookmarkImageProvider(bookmark),
                          ),
                          data: (image) => ZoomableHorizontalPageImage(
                            key: ValueKey(index),
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
                      disableGestures: zoomedIndexes.value.contains(
                        current.value,
                      ),
                      onLeftTap: () => goTo(currentIndex() - 1),
                      onRightTap: () => goTo(currentIndex() + 1),
                      onCenterTap: () => uiVisible.value = !uiVisible.value,
                    ),
                  ),
                  Align(
                    alignment: .topCenter,
                    child:
                        _ViewerHeader(
                              position:
                                  '${current.value + 1} / ${items.length}',
                              onClose: () => context.pop(),
                            )
                            .animate(target: uiVisible.value ? 1.0 : 0.0)
                            .show(duration: 10.ms, maintain: false)
                            .fadeIn(duration: overlayFadeDuration),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  final String position;
  final VoidCallback onClose;

  const _ViewerHeader({
    required this.position,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: LayoutConstants.smallEdgeInsets,
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            IconButton(
              icon: const Icon(KoverIcons.close),
              color: Colors.white,
              onPressed: onClose,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(
                  LayoutConstants.smallBorderRadius,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.smallPadding,
                  vertical: LayoutConstants.smallerPadding,
                ),
                child: Text(
                  position,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerEmpty extends StatelessWidget {
  final VoidCallback onClose;

  const _ViewerEmpty({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: .topLeft,
            child: IconButton(
              icon: const Icon(KoverIcons.close),
              color: Colors.white,
              onPressed: onClose,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                l.noBookmarks,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
