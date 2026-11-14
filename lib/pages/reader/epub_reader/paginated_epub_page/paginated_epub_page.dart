import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/horizontal_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/spreads_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/vertical_epub_page_view.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/extensions/epub_text_alignment.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

/// Paginate and layout a single EPUB page.
class PaginatedEpubPage extends HookWidget {
  final PaginatedEpubPageController controller;
  final dom.DocumentFragment html;
  final PaginatedEpubPageSettings settings;
  final String? resumeScrollId;
  final void Function(bool selected)? onSelectionChanged;
  final void Function(EpubAnchorTarget)? onAnchorTap;

  const new({
    super.key,
    required this.controller,
    required this.html,
    required this.settings,
    this.resumeScrollId,
    this.onSelectionChanged,
    this.onAnchorTap,
  });

  Map<String, Map<String, String>> computeThemeStyles(ThemeData theme) {
    return {
      '.${HtmlConstants.koverWrapperClass}': {
        'background-color': theme.colorScheme.surface.toCssRgba(),
        'color': theme.colorScheme.onSurface.toCssRgba(),
      },
      '.${HtmlConstants.resumeParagraphClass}': {
        'background-color': theme.colorScheme.tertiaryContainer
            .withAlpha(0xe0)
            .toCssRgba(),
        'color': theme.colorScheme.onTertiaryContainer.toCssRgba(),
      },
    };
  }

  Map<String, Map<String, String>> computeSettingsStyles(
    PaginatedEpubPageSettings settings,
  ) {
    final global = <String, String>{
      if (settings.fontFamily case final family?)
        'font-family': '"${family.replaceAll('"', "'")}"',
    };

    return {
      'p': {
        'margin-bottom': '${settings.paragraphSpacing}em',
        'text-align': settings.textAlignment.cssValue,
      },
      if (global.isNotEmpty) '*': global,
    };
  }

  @override
  Widget build(BuildContext context) {
    useListenable(controller);
    final theme = Theme.of(context);

    final styles = useMemoized(
      () => {
        ...computeThemeStyles(theme),
        ...computeSettingsStyles(settings),
      },
      [
        theme,
        settings.fontFamily,
        settings.removeParagraphIndent,
        settings.paragraphSpacing,
        settings.textAlignment,
      ],
    );

    final viewport = useState<Size?>(null);

    useEffect(() {
      controller.attachRoot(
        html,
        settings: settings,
        initialXpath: resumeScrollId,
        additionalStyles: styles,
      );
      return null;
    }, [controller, html, resumeScrollId]);

    useEffect(() {
      controller.updateStyles(styles);
      return null;
    }, [controller, styles]);

    useEffect(() {
      controller.updateSettings(settings);
      return null;
    }, [controller, settings]);

    final previousSettings = usePrevious(settings);
    useEffect(() {
      if (previousSettings == null) return null;
      if (previousSettings.layoutKey == settings.layoutKey) return null;
      controller.remeasure();
      return null;
    }, [controller, settings, previousSettings]);

    final root = controller.root;
    final measuring = controller.status == .measuring;

    return LayoutBuilder(
      builder: (context, contraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final newViewport = Size(contraints.maxWidth, contraints.maxHeight);

          if (viewport.value == newViewport) return;
          viewport.value = newViewport;

          controller.updateViewport(newViewport);
        });
        if (root == null || measuring) {
          return Stack(
            children: [
              Offstage(
                child: root == null
                    ? const SizedBox.shrink()
                    : EpubMeasurementsCollector(
                        html: root,
                        settings: settings,
                        cssEngine: controller.cssEngine,
                        constraints: contraints,
                        onMeasured: (measurements, viewport) {
                          controller.processMeasurements(
                            measurements,
                            viewport: viewport,
                            layoutKey: settings.layoutKey,
                          );
                        },
                      ),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }

        if (controller.subpageCount == 0) {
          return const SizedBox.shrink();
        }

        return SelectionArea(
          onSelectionChanged: (selection) {
            onSelectionChanged?.call(
              selection != null && selection.plainText.isNotEmpty,
            );
          },
          child: switch (settings.mode) {
            .horizontal => HorizontalEpubPageView(
              controller: controller,
              settings: settings,
              onAnchorTap: onAnchorTap,
            ),
            .vertical => VerticalEpubPageView(
              controller: controller,
              settings: settings,
              onAnchorTap: onAnchorTap,
            ),
            .spreads => SpreadsEpubPageView(
              controller: controller,
              settings: settings,
              onAnchorTap: onAnchorTap,
            ),
          },
        );
      },
    );
  }
}
