import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_measurements_collector.dart';
import 'package:kover/utils/logging.dart';
import 'package:material_ui/material_ui.dart';

class PaginatedEpubPage extends StatefulWidget {
  final PaginatedEpubPageController controller;
  final dom.DocumentFragment html;

  const new({super.key, required this.controller, required this.html});

  @override
  State<PaginatedEpubPage> createState() => _PaginatedEpubPageState();
}

class _PaginatedEpubPageState extends State<PaginatedEpubPage> {
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.attachRoot(widget.html);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PaginatedEpubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      widget.controller.attachRoot(widget.html);
    }
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void updateViewport(Size size) {
    if (_viewport != size) {
      setState(() {
        _viewport = size;
        widget.controller.viewportChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.root == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          updateViewport(Size(constraints.maxWidth, constraints.maxHeight));
        });

        if (widget.controller.status == .measuring) {
          return Stack(
            children: [
              Offstage(
                child: EpubMeasurementsCollector(
                  html: widget.controller.root!,
                  constraints: constraints,
                  onMeasured: (measurements) {
                    // Pages are laid out in the viewport, not in the full document.
                    final viewportHeight = constraints.maxHeight;
                    final pageHeight =
                        viewportHeight.isFinite && viewportHeight > 0
                        ? viewportHeight
                        : measurements.contentSize.height;

                    log.debug(
                      'Measurements collected',
                      attributes: {
                        'contentSize': measurements.contentSize,
                        'pageHeight': pageHeight,
                        'units': measurements.units.length,
                        'lines': measurements.units
                            .whereType<EpubLineUnit>()
                            .length,
                        'leaves': measurements.units
                            .whereType<EpubLeafUnit>()
                            .length,
                      },
                    );

                    widget.controller.processMeasurements(
                      measurements,
                      pageHeight: pageHeight,
                    );

                    log.debug(
                      'Pagination completed',
                      attributes: {
                        'pageHeight': pageHeight,
                        'subpages': widget.controller.subpageCount,
                      },
                    );
                  },
                ),
              ),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        final subpageCount = widget.controller.subpageCount;
        if (subpageCount == 0) {
          return const SizedBox.shrink();
        }

        return PageView.builder(
          itemCount: subpageCount,
          itemBuilder: (context, index) {
            return HtmlWidget(
              widget.controller.getSubpage(index),
              factoryBuilder: () => PaginatedEpubWidgetFactory(),
            );
          },
        );
      },
    );
  }
}
