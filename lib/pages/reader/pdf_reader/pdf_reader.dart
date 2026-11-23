import 'dart:async';
import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/pages/reader/pdf_reader/horizontal_page_layout.dart';
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

/// Goes to [pageNumber] at [zoomFactor] times [fitZoom], centred horizontally and
/// showing the top of the page when it is taller than the view.
Future<void> _goToPage({
  required PdfViewerController controller,
  required int pageNumber,
  required double fitZoom,
  required double zoomFactor,
  Duration duration = Duration.zero,
}) {
  final zoom = (fitZoom * zoomFactor).clamp(
    controller.minScale,
    controller.maxScale,
  );
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
    final fitZoom = useState(1.0);
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
    final zoomFactor = model.value?.settings.defaultZoom;

    // Apply a changed default zoom to the current page.
    useEffect(() {
      if (zoomFactor == null || !controller.isReady) return null;
      // Effects run during build; the viewer must not change its matrix until after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final page = ref.read(navProvider).value?.currentPage;
        if (!context.mounted || !controller.isReady || page == null) return;
        await _goToPage(
          controller: controller,
          pageNumber: page + 1,
          fitZoom: fitZoom.value,
          zoomFactor: zoomFactor,
        );
      });
      return null;
    }, [zoomFactor]);

    ref.listen(navProvider, (previous, next) async {
      next.whenData((next) async {
        if (!controller.isReady || next.fromObserver) return;

        if (previous?.value?.currentPage != next.currentPage) {
          lastUpdateFromProvider.value = true;
          await _goToPage(
            controller: controller,
            pageNumber: next.currentPage + 1,
            fitZoom: fitZoom.value,
            zoomFactor: model.value?.settings.defaultZoom ?? 1.0,
            duration: model.value?.reduceAnimations ?? false
                ? Duration.zero
                : LayoutConstants.pageSlideDuration,
          );
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
              if (page == null) return;
              unawaited(
                _goToPage(
                  controller: controller,
                  pageNumber: page + 1,
                  fitZoom: fitZoom.value,
                  zoomFactor: data.settings.defaultZoom,
                ),
              );
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

              final layoutStrategy = switch (data.settings.readerMode) {
                .vertical => const SequentialPagesLayout(),
                .horizontal => HorizontalPageLayout(
                  readDirection: data.commonSettings.readDirection,
                ),
              };

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
                    fitZoom.value = controller.currentZoom;
                    if (data.settings.defaultZoom > 1.0) {
                      unawaited(
                        _goToPage(
                          controller: controller,
                          pageNumber: data.reader.initialPage + 1,
                          fitZoom: fitZoom.value,
                          zoomFactor: data.settings.defaultZoom,
                        ),
                      );
                    }
                    toc.value = await document.loadOutline();
                  },
                  onPageChanged: (page) {
                    if (page == null) return;

                    ref
                        .read(navProvider.notifier)
                        .jumpToPage(page - 1, fromObserver: true);
                  },
                  layoutStrategy: layoutStrategy,
                  calculateCurrentPageNumber:
                      layoutStrategy is HorizontalPageLayout
                      ? layoutStrategy.calculateCurrentPageNumber
                      : null,
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
