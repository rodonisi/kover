import 'dart:async';
import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/pages/reader/pdf_reader/pdf_reader_provider.dart';
import 'package:kover/pages/reader/pdf_reader/pdf_toc_drawer.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfControllerHook extends Hook<PdfViewerController> {
  const PdfControllerHook();

  @override
  PdfViewerControllerHookState createState() => PdfViewerControllerHookState();
}

class PdfViewerControllerHookState
    extends HookState<PdfViewerController, PdfControllerHook> {
  late final PdfViewerController controller;

  @override
  void initHook() {
    super.initHook();
    controller = PdfViewerController();
  }

  @override
  PdfViewerController build(BuildContext context) => controller;
}

PdfViewerController usePdfViewerController() => use(const PdfControllerHook());

/// Zooms to [percent] of the viewer's fit zoom on [pageNumber], centred horizontally and
/// showing the top of the page when it is taller than the view.
Future<void> _goToPageZoomed(
  PdfViewerController controller,
  int pageNumber,
  double percent, {
  Duration duration = Duration.zero,
}) {
  final fit = controller.coverScale.clamp(
    controller.minScale,
    controller.maxScale,
  );
  final zoom = min(fit * percent / 100, controller.maxScale);
  final index = pageNumber.clamp(1, controller.pageCount) - 1;
  final page = controller.layout.pageLayouts[index];
  final y = min(
    page.center.dy,
    page.top + controller.viewSize.height / zoom / 2,
  );
  return controller.goTo(
    controller.calcMatrixFor(Offset(page.center.dx, y), zoom: zoom),
    duration: duration,
  );
}

class PdfReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int? readingListId;

  const PdfReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
    this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePdfViewerController();
    final toc = useState<List<PdfOutlineNode>>([]);
    final defaultZoom = useState(1.0);
    final lastUpdateFromProvider = useState(false);
    final hasSelection = useState(false);

    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );

    final model = ref.watch(
      pdfReaderProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ),
    );

    final pdf = ref.watch(pdfProvider(chapterId: chapterId));
    final zoomPercent = model.value?.settings.defaultZoom;

    // Apply a changed default zoom to the current page.
    useEffect(() {
      if (zoomPercent == null || !controller.isReady) return null;
      // Effects run during build; the viewer must not change its matrix until after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final page = ref.read(navProvider).value?.currentPage;
        if (!context.mounted || !controller.isReady || page == null) return;
        if (zoomPercent > 100) {
          await _goToPageZoomed(controller, page + 1, zoomPercent);
        } else {
          await controller.setZoom(
            controller.centerPosition,
            defaultZoom.value,
          );
          await controller.goToPage(pageNumber: page + 1, duration: .zero);
        }
      });
      return null;
    }, [zoomPercent]);

    ref.listen(navProvider, (previous, next) async {
      next.whenData((next) async {
        if (!controller.isReady || next.fromObserver) return;

        if (previous?.value?.currentPage != next.currentPage) {
          lastUpdateFromProvider.value = true;
          final duration = model.value?.reduceAnimations ?? false
              ? Duration.zero
              : LayoutConstants.pageSlideDuration;
          final percent = model.value?.settings.defaultZoom ?? 100;
          if (percent > 100) {
            await _goToPageZoomed(
              controller,
              next.currentPage + 1,
              percent,
              duration: duration,
            );
          } else {
            await controller.goToPage(
              pageNumber: next.currentPage + 1,
              duration: duration,
            );
          }
        }
      });
    });

    return Async(
      asyncValue: model,
      data: (data) {
        return ReaderOverlay(
          chapterId: chapterId,
          seriesId: seriesId,
          readingListId: readingListId,
          disableGestures: hasSelection.value,
          onNextPage: () {
            ref.read(navProvider.notifier).nextPage();
          },
          onPreviousPage: () {
            ref.read(navProvider.notifier).previousPage();
          },
          onJumpToPage: (page) =>
              ref.read(navProvider.notifier).jumpToPage(page),

          endDrawer: toc.value.isNotEmpty
              ? PdfTocDrawer(
                  seriesId: seriesId,
                  chapterId: chapterId,
                  readingListId: readingListId,
                  controller: controller,
                  toc: toc.value,
                )
              : null,
          extraControls: _PdfExtraControls(
            controller: controller,
            onResetZoom: () {
              final page = ref.read(navProvider).value?.currentPage;
              if (data.settings.defaultZoom > 100 && page != null) {
                unawaited(
                  _goToPageZoomed(
                    controller,
                    page + 1,
                    data.settings.defaultZoom,
                  ),
                );
              } else {
                controller.setZoom(
                  controller.centerPosition,
                  defaultZoom.value,
                );
              }
            },
          ),
          child: Async(
            asyncValue: pdf,
            data: (pdf) {
              final scrollPhysics =
                  (data.commonSettings.navigationGersturesEnabled &&
                          !data.reduceAnimations) ||
                      data.settings.readerMode == .vertical
                  ? null
                  : const NeverScrollableScrollPhysics();
              final content = PdfViewer.data(
                pdf.data,
                controller: controller,
                sourceName: chapterId.toString(),
                initialPageNumber: data.reader.initialPage + 1,
                params: PdfViewerParams(
                  scrollPhysics: scrollPhysics,
                  panAxis:
                      data.settings.lockHorizontalPan &&
                          data.settings.readerMode == .vertical
                      ? .vertical
                      : .free,
                  textSelectionParams: PdfTextSelectionParams(
                    onTextSelectionChange: (selection) {
                      if (selection.hasSelectedText != hasSelection.value) {
                        hasSelection.value = selection.hasSelectedText;
                      }
                    },
                  ),
                  onViewerReady: (document, controller) async {
                    defaultZoom.value = controller.currentZoom;
                    if (data.settings.defaultZoom > 100) {
                      unawaited(
                        _goToPageZoomed(
                          controller,
                          data.reader.initialPage + 1,
                          data.settings.defaultZoom,
                        ),
                      );
                    }
                    toc.value = await document.loadOutline();
                  },
                  onPageChanged: (page) {
                    if (page == null) return;

                    // Workaround for PdfViewer reporting 1-based page number
                    // in layout order, but only some times. It seems jumpToPage
                    // always goes by document order. The update from the provider
                    // alwo fires an event with the same page, while the next ones
                    // go back by layout order.
                    final int navIndex;
                    if (data.commonSettings.readDirection == .rightToLeft &&
                        data.settings.readerMode == .horizontal) {
                      navIndex = lastUpdateFromProvider.value
                          ? page - 1
                          : (data.reader.totalPages - page - 1);
                    } else {
                      navIndex = page - 1;
                    }

                    ref
                        .read(navProvider.notifier)
                        .jumpToPage(navIndex, fromObserver: true);

                    lastUpdateFromProvider.value = false;
                  },
                  layoutPages: switch (data.settings.readerMode) {
                    .vertical => null,
                    .horizontal => (pages, params) => horizontalLayout(
                      pages,
                      params,
                      data.commonSettings.readDirection,
                    ),
                  },
                ),
              );

              if (data.settings.ignoreSafeAreas) {
                return content;
              }

              return SafeArea(child: content);
            },
          ),
        );
      },
    );
  }

  PdfPageLayout horizontalLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
    ReadDirection readDirection,
  ) {
    final height =
        pages.fold(0.0, (prev, page) => max(prev, page.height)) +
        params.margin * 2;
    final width = pages.fold(
      params.margin,
      (prev, page) => prev + page.width + params.margin,
    );
    final pageLayouts = <Rect>[];
    double x = params.margin;
    for (var page in pages) {
      final dirX = switch (readDirection) {
        .leftToRight => x,
        .rightToLeft => width - x - page.width,
      };

      pageLayouts.add(
        Rect.fromLTWH(
          dirX,
          (height - page.height) / 2, // center vertically
          page.width,
          page.height,
        ),
      );

      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(width, height),
    );
  }
}

class _PdfExtraControls extends StatelessWidget {
  const _PdfExtraControls({
    required this.controller,
    required this.onResetZoom,
  });

  final PdfViewerController controller;
  final VoidCallback onResetZoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .end,
      spacing: LayoutConstants.mediumPadding,
      children: [
        IconButton(
          onPressed: () {
            controller.zoomUp();
          },
          icon: const Icon(KoverIcons.zoomIn),
        ),
        IconButton(
          onPressed: () {
            controller.zoomDown();
          },
          icon: const Icon(KoverIcons.zoomOut),
        ),
        IconButton(
          onPressed: onResetZoom,
          icon: const Icon(KoverIcons.zoomReset),
        ),
      ],
    );
  }
}
