import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_anchor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:material_ui/material_ui.dart';

/// Shared content wrapper used by both rendering and measurement.
class PaginatedEpubPageContent extends StatelessWidget {
  final String html;
  final PaginatedEpubPageSettings settings;
  final Size viewport;
  final CssEngine cssEngine;
  final Key? anchorKey;
  final WidgetFactory Function()? factoryBuilder;
  final void Function(EpubAnchorTarget)? onAnchorTap;

  const PaginatedEpubPageContent({
    super.key,
    required this.html,
    required this.settings,
    required this.viewport,
    required this.cssEngine,
    this.anchorKey,
    this.factoryBuilder,
    this.onAnchorTap,
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
          html,
          factoryBuilder:
              factoryBuilder ??
              () => PaginatedEpubWidgetFactory(
                viewport: viewport,
                removeParagraphIndent: settings.removeParagraphIndent,
                onAnchorTap: onAnchorTap,
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
