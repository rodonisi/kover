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
    );

    final model = ref.watch(
      pdfReaderProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ),
    );

    final pdf = ref.watch(pdfProvider(chapterId: chapterId));

    ref.listen(navProvider, (previous, next) async {
      next.whenData((next) async {
        if (!controller.isReady || next.fromObserver) return;

        if (previous?.value?.currentPage != next.currentPage) {
          lastUpdateFromProvider.value = true;
          await controller.goToPage(
            pageNumber: next.currentPage + 1,
            duration: model.value?.reduceAnimations ?? false
                ? .zero
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
            if (data.commonSettings.readDirection == .leftToRight) {
              ref.read(navProvider.notifier).nextPage();
            } else {
              ref.read(navProvider.notifier).previousPage();
            }
          },
          onPreviousPage: () {
            if (data.commonSettings.readDirection == .leftToRight) {
              ref.read(navProvider.notifier).previousPage();
            } else {
              ref.read(navProvider.notifier).nextPage();
            }
          },
          onJumpToPage: (page) =>
              ref.read(navProvider.notifier).jumpToPage(page),

          endDrawer: toc.value.isNotEmpty
              ? PdfTocDrawer(
                  seriesId: seriesId,
                  chapterId: chapterId,
                  controller: controller,
                  toc: toc.value,
                )
              : null,
          extraControls: _PdfExtraControls(
            controller: controller,
            defaultZoom: defaultZoom,
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
                    toc.value = await document.loadOutline();
                    defaultZoom.value = controller.currentZoom;
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
    required this.defaultZoom,
  });

  final PdfViewerController controller;
  final ValueNotifier<double> defaultZoom;

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
          onPressed: () {
            controller.setZoom(
              controller.centerPosition,
              defaultZoom.value,
            );
          },
          icon: const Icon(KoverIcons.zoomReset),
        ),
      ],
    );
  }
}
