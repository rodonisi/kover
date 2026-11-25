import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_anchor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/selection/epub_selection_registry.dart';
import 'package:material_ui/material_ui.dart';

/// Shared content wrapper used by both rendering and measurement.
class PaginatedEpubPageContent extends StatelessWidget {
  final String html;
  final PaginatedEpubPageSettings settings;
  final List<PaginatedEpubAnnotation> annotations;
  final Size viewport;
  final CssEngine cssEngine;
  final Key? anchorKey;
  final WidgetFactory Function()? factoryBuilder;
  final void Function(EpubAnchorTarget)? onAnchorTap;
  final void Function(PaginatedEpubAnnotation)? onAnnotationTap;
  final EpubSelectionRegistry? selectionRegistry;

  const PaginatedEpubPageContent({
    super.key,
    required this.html,
    required this.settings,
    required this.viewport,
    required this.cssEngine,
    this.anchorKey,
    this.factoryBuilder,
    this.onAnchorTap,
    this.onAnnotationTap,
    this.selectionRegistry,
    this.annotations = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      wordSpacing: settings.wordSpacing,
      letterSpacing: settings.letterSpacing,
      fontFamily: settings.fontFamily,
    );

    return Padding(
      padding: .symmetric(
        horizontal: settings.horizontalMarginSize,
        vertical: settings.mode == .vertical ? 0 : settings.verticalMarginSize,
      ),
      child: EpubMeasureAnchor(
        key: anchorKey,
        child: HtmlWidget(
          key: ValueKey(Object.hashAll(annotations)),
          html,
          factoryBuilder:
              factoryBuilder ??
              () => PaginatedEpubWidgetFactory(
                viewport: viewport,
                removeParagraphIndent: settings.removeParagraphIndent,
                onAnchorTap: onAnchorTap,
                annotations: annotations,
                onAnnotationTap: onAnnotationTap,
                selectionRegistry: selectionRegistry,
              ),
          customStylesBuilder: (element) =>
              cssEngine.stylesFor(element: element),
          textStyle: textStyle,
          rebuildTriggers: [cssEngine.stylesRevision],
        ),
      ),
    );
  }
}
