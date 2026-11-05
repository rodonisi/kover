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
import 'package:kover/riverpod/providers/settings/pdf_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
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

bool _isCropping(PdfReaderSettingsState settings) =>
    settings.readerMode == .horizontal &&
    (settings.horizontalCrop > 0 || settings.verticalCrop > 0);

/// Page area left after cropping, relative to the page's top-left corner.
Rect _cropRect(Size size, PdfReaderSettingsState settings) {
  final dx = size.width * settings.horizontalCrop / 100;
  final dy = size.height * settings.verticalCrop / 100;
  return Rect.fromLTRB(dx, dy, size.width - dx, size.height - dy);
}

/// Smallest document padding that lets every cropped page be centred when fitted to [viewSize].
EdgeInsets _cropBoundary(
  PdfPageLayout layout,
  PdfReaderSettingsState settings,
  Size viewSize,
) {
  final doc = layout.documentSize;
  var (left, top, right, bottom) = (0.0, 0.0, 0.0, 0.0);
  for (final page in layout.pageLayouts) {
    final crop = _cropRect(page.size, settings).shift(page.topLeft);
    final zoom = min(
      viewSize.width / crop.width,
      viewSize.height / crop.height,
    );
    final half = viewSize / zoom / 2;
    left = max(left, half.width - crop.center.dx);
    right = max(right, crop.center.dx + half.width - doc.width);
    top = max(top, half.height - crop.center.dy);
    bottom = max(bottom, crop.center.dy + half.height - doc.height);
  }
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

/// Zooms so the page area left after cropping fills the view.
Future<void> _fitPage(
  PdfViewerController controller,
  PdfReaderSettingsState settings,
  int pageNumber, {
  Duration duration = Duration.zero,
}) {
  final pages = controller.document.pages;
  final index = pageNumber.clamp(1, pages.length) - 1;
  final size = controller.layout.pageLayouts[index].size;
  final rect = _cropRect(size, settings);
  return controller.goToRectInsidePage(
    pageNumber: index + 1,
    rect: rect.toPdfRect(page: pages[index], scaledPageSize: size),
    anchor: .all,
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
    final settings = model.value?.settings;
    final cropping = settings != null && _isCropping(settings);
    final wasCropping = useRef(false);
    final latestSettings = useRef(settings)..value = settings;
    final viewSize = useState<Size?>(null);
    // Forces a rebuild so crop boundaries use the viewer's current layout.
    final layoutTick = useState(0);
    final resizeTimer = useRef<Timer?>(null);
    // Bumped by navigation so pending refits don't override a page turn.
    final fitGeneration = useRef(0);
    useEffect(
      () =>
          () => resizeTimer.value?.cancel(),
      const [],
    );

    final cropBoundary =
        cropping && viewSize.value != null && controller.isReady
        ? _cropBoundary(controller.layout, settings, viewSize.value!)
        : null;

    // Rebuilds with the viewer's current layout and size, then refits the current page
    // once the resulting boundaries are applied.
    void scheduleRefit({bool force = false}) {
      final generation = fitGeneration.value;
      bool stale() =>
          !context.mounted ||
          generation != fitGeneration.value ||
          !controller.isReady;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (stale()) return;
        viewSize.value = controller.viewSize;
        layoutTick.value++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final settings = latestSettings.value;
          if (stale() || settings == null) return;
          if (settings.readerMode != .horizontal) return;
          if (!(force || _isCropping(settings))) return;
          final pageNumber = controller.pageNumber;
          if (pageNumber == null) return;
          unawaited(_fitPage(controller, settings, pageNumber));
        });
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    // Re-fit the current page when crop settings change, including back to uncropped.
    useEffect(() {
      if (settings?.readerMode == .horizontal &&
          (cropping || wasCropping.value)) {
        scheduleRefit(force: true);
      }
      wasCropping.value = cropping;
      return null;
    }, [cropping, settings?.horizontalCrop, settings?.verticalCrop]);

    ref.listen(navProvider, (previous, next) async {
      next.whenData((next) async {
        if (!controller.isReady || next.fromObserver) return;

        if (previous?.value?.currentPage != next.currentPage) {
          resizeTimer.value?.cancel();
          fitGeneration.value++;
          lastUpdateFromProvider.value = true;
          final duration = model.value?.reduceAnimations ?? false
              ? Duration.zero
              : LayoutConstants.pageSlideDuration;
          final settings = model.value?.settings;
          if (settings != null && _isCropping(settings)) {
            await _fitPage(
              controller,
              settings,
              next.currentPage + 1,
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
              final pageNumber = controller.pageNumber;
              if (_isCropping(data.settings) && pageNumber != null) {
                unawaited(_fitPage(controller, data.settings, pageNumber));
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
                  // Lets a cropped page centre at document edges.
                  boundaryMargin: cropBoundary,
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
                    toc.value = await document.loadOutline();
                    defaultZoom.value = controller.currentZoom;
                    if (_isCropping(data.settings)) scheduleRefit();
                  },
                  onViewSizeChanged: (viewSize, oldViewSize, controller) {
                    if (oldViewSize == null || !cropping) return;
                    // Must not change the matrix synchronously; this may run during build.
                    resizeTimer.value?.cancel();
                    resizeTimer.value = Timer(
                      const Duration(milliseconds: 200),
                      scheduleRefit,
                    );
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
