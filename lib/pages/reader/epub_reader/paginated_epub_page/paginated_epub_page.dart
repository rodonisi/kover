import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/render_html.dart';
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
  Timer? _viewportDebounce;

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
          if (_viewportDebounce != null) {
            _viewportDebounce!.cancel();
          }
          _viewportDebounce = Timer(const Duration(milliseconds: 100), () {
            updateViewport(Size(constraints.maxWidth, constraints.maxHeight));
          });
        });

        if (widget.controller.status == .measuring) {
          return Stack(
            children: [
              Offstage(
                child: EpubMeasurementsCollector(
                  html: widget.controller.root!,
                  viewport: _viewport,
                  onMeasured: (measurements) {
                    widget.controller.processMeasurements(
                      measurements,
                      pageHeight: _viewport.height,
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
            return OverflowBox(
              maxHeight: double.infinity,
              child: RenderHtml(
                html: widget.controller.getSubpage(index),
                factoryBuilder: () =>
                    PaginatedEpubWidgetFactory(viewport: _viewport),
              ),
            );
          },
        );
      },
    );
  }
}
