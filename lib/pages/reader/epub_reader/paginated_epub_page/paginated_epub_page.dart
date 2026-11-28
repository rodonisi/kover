import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/selection/epub_selection_registry.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/horizontal_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/spreads_epub_page_view.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/views/vertical_epub_page_view.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/extensions/epub_text_alignment.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// Paginate and layout a single EPUB page.
class PaginatedEpubPage extends HookWidget {
  final PaginatedEpubPageController controller;
  final dom.DocumentFragment html;
  final PaginatedEpubPageSettings settings;
  final List<PaginatedEpubAnnotation> annotations;
  final String? resumeScrollId;
  final void Function(bool selected)? onSelectionChanged;
  final void Function(EpubAnchorTarget)? onAnchorTap;
  final Widget Function(BuildContext context, int annotationId)?
  annotationSheetBuilder;
  final Widget Function(BuildContext context, AnnotationDraft draft)?
  draftSheetBuilder;

  const new({
    super.key,
    required this.controller,
    required this.html,
    required this.settings,
    this.annotations = const [],
    this.resumeScrollId,
    this.onSelectionChanged,
    this.onAnchorTap,
    this.annotationSheetBuilder,
    this.draftSheetBuilder,
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
    final selectionRegistry = useMemoized(EpubSelectionRegistry.new);

    useEffect(() {
      controller.attachRoot(
        html,
        settings: settings,
        initialXpath: resumeScrollId,
        additionalStyles: styles,
        annotations: annotations,
      );
      return null;
    }, [controller, html, resumeScrollId]);

    useEffect(() {
      controller.updateAnnotations(annotations);
      return null;
    }, [controller, annotations]);

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

    void showSheet(WidgetBuilder builder) {
      final animation = settings.reduceAnimations
          ? const AnimationStyle(duration: .zero, reverseDuration: .zero)
          : null;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          maxWidth: LayoutBreakpoints.medium,
        ),
        sheetAnimationStyle: animation,
        builder: builder,
      );
    }

    void handleAnnotationTap(PaginatedEpubAnnotation annotation) {
      final builder = annotationSheetBuilder;
      if (builder == null) return;

      showSheet((sheetContext) => builder(sheetContext, annotation.id));
    }

    void handleAnnotate(SelectableRegionState selection) {
      final builder = draftSheetBuilder;
      final draft = selectionRegistry.resolveDraft();
      if (builder == null || draft == null) return;

      if (!controller.canHighlight(draft)) {
        selection.hideToolbar(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).annotationSelectionUnsupported,
            ),
          ),
        );
        return;
      }

      selection.hideToolbar();
      selection.clearSelection();
      showSheet((sheetContext) => builder(sheetContext, draft));
    }

    Widget buildSelectionMenu(
      BuildContext context,
      SelectableRegionState selection,
    ) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: selection.contextMenuAnchors,
        buttonItems: [
          ...selection.contextMenuButtonItems,
          if (draftSheetBuilder != null &&
              selectionRegistry.resolveDraft() != null)
            ContextMenuButtonItem(
              label: AppLocalizations.of(context).annotate,
              onPressed: () => handleAnnotate(selection),
            ),
        ],
      );
    }

    final void Function(PaginatedEpubAnnotation)? annotationTapHandler =
        annotationSheetBuilder == null ? null : handleAnnotationTap;

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
                        annotations: annotations,
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
          contextMenuBuilder: buildSelectionMenu,
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
              onAnnotationTap: annotationTapHandler,
              selectionRegistry: selectionRegistry,
            ),
            .vertical => VerticalEpubPageView(
              controller: controller,
              settings: settings,
              onAnchorTap: onAnchorTap,
              onAnnotationTap: annotationTapHandler,
              selectionRegistry: selectionRegistry,
            ),
            .spreads => SpreadsEpubPageView(
              controller: controller,
              settings: settings,
              onAnchorTap: onAnchorTap,
              onAnnotationTap: annotationTapHandler,
              selectionRegistry: selectionRegistry,
            ),
          },
        );
      },
    );
  }
}
