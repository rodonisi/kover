import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/utils/html_constants.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_styles.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/horizontal_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/spreads_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/vertical_epub_page_view.dart';
import 'package:material_ui/material_ui.dart';

class PaginatedEpubPage extends HookWidget {
  final PaginatedEpubPageController controller;
  final dom.DocumentFragment html;
  final PaginatedEpubPageSettings settings;
  final Map<String, Map<String, String>> additionalStyles;
  final Map<String, String> rootStyles;
  final Map<String, String> highlightStyles;
  final String? resumeScrollId;
  final void Function(bool selected)? onSelectionChanged;

  const new({
    super.key,
    required this.controller,
    required this.html,
    required this.settings,
    this.additionalStyles = const {},
    this.rootStyles = const {},
    this.highlightStyles = const {},
    this.resumeScrollId,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    useListenable(controller);

    final mergedStyles = useMemoized(
      () => mergeStyles([
        additionalStyles,
        if (rootStyles.isNotEmpty)
          {'.${HtmlConstants.koverWrapperClass}': rootStyles},
        settingsStyles(settings),
        if (highlightStyles.isNotEmpty)
          {'.${HtmlConstants.resumeClass}': highlightStyles},
      ]),
      [additionalStyles, rootStyles, highlightStyles, settings],
    );

    useEffect(() {
      controller.attachRoot(
        html,
        settings: settings,
        initialXpath: resumeScrollId,
        additionalStyles: mergedStyles,
      );
      return null;
    }, [controller, html, resumeScrollId]);

    useEffect(() {
      controller.updateStyles(mergedStyles);
      return null;
    }, [controller, mergedStyles]);

    useEffect(() {
      controller.updateSettings(settings);
      return null;
    }, [controller, settings]);

    final previousSettings = usePrevious(settings);
    useEffect(() {
      if (previousSettings == null || previousSettings == settings) return null;
      controller.remeasure();
      return null;
    }, [controller, settings, previousSettings]);

    final root = controller.root;
    final measuring = controller.status == .measuring;

    return Stack(
      children: [
        Positioned.fill(
          child: Offstage(
            child: root == null
                ? const SizedBox.shrink()
                : EpubMeasurementsCollector(
                    html: root,
                    settings: settings,
                    cssEngine: controller.cssEngine,
                    enabled: measuring,
                    onViewportChanged: controller.viewportChanged,
                    onMeasured: (measurements, viewport) {
                      controller.processMeasurements(
                        measurements,
                        viewport: viewport,
                      );
                    },
                  ),
          ),
        ),
        if (root == null || measuring)
          const Center(child: CircularProgressIndicator())
        else if (controller.subpageCount == 0)
          const SizedBox.shrink()
        else
          SelectionArea(
            onSelectionChanged: (selection) {
              onSelectionChanged?.call(
                selection != null && selection.plainText.isNotEmpty,
              );
            },
            child: switch (settings.mode) {
              .horizontal => HorizontalEpubPageView(
                controller: controller,
                settings: settings,
              ),
              .vertical => VerticalEpubPageView(
                controller: controller,
                settings: settings,
              ),
              .spreads => SpreadsEpubPageView(
                controller: controller,
                settings: settings,
              ),
            },
          ),
      ],
    );
  }
}
