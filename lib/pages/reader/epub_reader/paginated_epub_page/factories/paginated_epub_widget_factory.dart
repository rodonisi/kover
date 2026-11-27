import 'dart:math' as math;

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/selection/epub_selection_registry.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/widgets/util/link_hit_region.dart';

/// A [WidgetFactory] that adjusts rendering for paginated EPUB content.
class PaginatedEpubWidgetFactory({
  final Size viewport = const Size(double.infinity, double.infinity),
  final bool removeParagraphIndent = false,
  final void Function(EpubAnchorTarget)? onAnchorTap,
  Iterable<PaginatedEpubAnnotation> annotations = const [],
  final void Function(PaginatedEpubAnnotation)? onAnnotationTap,

  /// Receives every rendered text block, so selections can be annotated.
  final EpubSelectionRegistry? selectionRegistry,
  final int subpageIndex = 0,
}) extends WidgetFactory {
  // Runs after background styling so the saved slot color wins.
  static const _annotationPriority = 9007199254740991;

  final Map<int, PaginatedEpubAnnotation> _annotations = {
    for (final annotation in annotations) annotation.id: annotation,
  };

  late final BuildOp _textIndentOp = BuildOp(
    alwaysRenderBlock: false,
    debugLabel: 'epub-text-indent',
    onParsed: (tree) {
      _applyTextIndent(tree);
      return tree;
    },
  );

  late final BuildOp _annotationOp = BuildOp(
    alwaysRenderBlock: false,
    debugLabel: 'epub-annotation',
    onParsed: _applyAnnotation,
    onRenderInline: _applyAnnotationColor,
    priority: _annotationPriority,
    onRenderBlock: (tree, placeholder) {
      final recognizer = tree.getNonInherited<GestureRecognizer>();
      if (recognizer == null) return placeholder;

      return placeholder.wrapWith((context, child) {
        if (child == widget0) return null;
        return buildGestureDetector(tree, child, recognizer);
      });
    },
  );

  @override
  void parse(BuildTree meta) {
    meta.register(_textIndentOp);
    if (meta.element.localName == HtmlConstants.kavitaHighlightElementTag) {
      meta.register(_annotationOp);
    }

    super.parse(meta);
  }

  @override
  GestureRecognizer? buildGestureRecognizer(
    BuildTree tree, {
    GestureTapCallback? onTap,
  }) {
    if (onAnnotationTap case final onAnnotationTap?) {
      final annotation = _annotationFor(tree.element);
      if (annotation != null) {
        return super.buildGestureRecognizer(
          tree,
          onTap: () => onAnnotationTap(annotation),
        );
      }
    }

    if (onAnchorTap != null) {
      final target = EpubAnchorTarget.fromElement(tree.element);
      if (target != null) {
        return super.buildGestureRecognizer(
          tree,
          onTap: () => onAnchorTap!(target),
        );
      }
    }

    return super.buildGestureRecognizer(tree, onTap: onTap);
  }

  @override
  Widget? buildGestureDetector(
    BuildTree tree,
    Widget child,
    GestureRecognizer recognizer,
  ) {
    final built = super.buildGestureDetector(tree, child, recognizer);
    if (built == null) return built;

    final isAnnotation =
        onAnnotationTap != null && _annotationFor(tree.element) != null;
    final isAnchor =
        onAnchorTap != null &&
        EpubAnchorTarget.fromElement(tree.element) != null;
    if (!isAnnotation && !isAnchor) return built;

    return LinkHitRegion(child: built);
  }

  @override
  Widget? buildDecoration(
    BuildTree tree,
    Widget child, {
    BoxBorder? border,
    BorderRadius? borderRadius,
    Color? color,
    DecorationImage? image,
  }) {
    final annotation = _annotationFor(tree.element);
    return super.buildDecoration(
      tree,
      child,
      border: border,
      borderRadius: borderRadius,
      color: annotation?.color ?? color,
      image: image,
    );
  }

  @override
  Widget? buildText(
    BuildTree tree,
    InheritedProperties resolved,
    InlineSpan text,
  ) {
    final child = super.buildText(tree, resolved, text);
    final registry = selectionRegistry;
    if (child == null || registry == null) return child;

    return EpubSelectableBlock(
      registry: registry,
      element: tree.element,
      subpageIndex: subpageIndex,
      child: child,
    );
  }

  @override
  Widget? buildImageWidget(BuildTree meta, ImageSource src) {
    final image = super.buildImageWidget(meta, src);
    if (image is! Image || !viewport.height.isFinite) return image;

    return Image(
      key: image.key,
      image: image.image,
      frameBuilder: image.frameBuilder,
      loadingBuilder: image.loadingBuilder,
      errorBuilder: image.errorBuilder,
      semanticLabel: image.semanticLabel,
      excludeFromSemantics: image.excludeFromSemantics,
      width: image.width,
      height: image.height,
      color: image.color,
      opacity: image.opacity,
      colorBlendMode: image.colorBlendMode,
      fit: .contain,
      alignment: image.alignment,
      repeat: image.repeat,
      centerSlice: image.centerSlice,
      matchTextDirection: image.matchTextDirection,
      gaplessPlayback: image.gaplessPlayback,
      isAntiAlias: image.isAntiAlias,
      filterQuality: image.filterQuality,
    );
  }

  @override
  StylesMap? customStylesBuilder(dom.Element element) {
    final styles = Map<String, String>.of(
      super.customStylesBuilder(element) ?? const {},
    );

    if (element.classes.contains(HtmlConstants.koverWrapperClass)) {
      return styles..removeWhere(
        (key, _) =>
            key.startsWith('margin') ||
            key.startsWith('padding') ||
            key == 'width' ||
            key == 'min-width' ||
            key == 'max-width',
      );
    }

    if (element.attributes.containsKey(
      HtmlConstants.trimStartAttribute,
    )) {
      styles['margin-top'] = '0';
      element.attributes['style'] = _appendStyle(
        element.attributes['style'],
        'margin-top: 0',
      );
    }

    if (element.attributes.containsKey(HtmlConstants.trimEndAttribute)) {
      styles['margin-bottom'] = '0';
      element.attributes['style'] = _appendStyle(
        element.attributes['style'],
        'margin-bottom: 0',
      );
    }

    if (element.localName == HtmlConstants.kavitaHighlightElementTag) {
      final annotation = _annotationFor(element);
      if (annotation != null) {
        styles['background-color'] = annotation.color.toCssRgba();
      }
    }

    if (element.localName != 'img') return styles;

    if (viewport.height.isFinite) {
      styles['max-height'] = '${viewport.height}px';
    }

    final width = double.tryParse(element.attributes['width'] ?? '');
    final height = double.tryParse(element.attributes['height'] ?? '');
    if (width == null || height == null) return styles;

    final fitted = _fit(Size(width, height));
    return styles
      ..['width'] = '${fitted.width}px'
      ..['height'] = '${fitted.height}px';
  }

  BuildTree _applyAnnotation(BuildTree tree) {
    final annotation = _annotationFor(tree.element);
    if (annotation == null || onAnnotationTap == null) return tree;

    final recognizer = buildGestureRecognizer(tree);
    if (recognizer == null) return tree;

    return tree
      ..inherit(_annotationRecognizer, recognizer)
      ..setNonInherited(recognizer);
  }

  void _applyAnnotationColor(BuildTree tree) {
    final annotation = _annotationFor(tree.element);
    if (annotation == null) return;
    tree.inherit(_annotationHighlight, annotation.color);
  }

  PaginatedEpubAnnotation? _annotationFor(dom.Element element) {
    if (element.localName != HtmlConstants.kavitaHighlightElementTag) {
      return null;
    }

    final id = int.tryParse(
      element.attributes[HtmlConstants.koverAnnotationIdAttribute]?.trim() ??
          '',
    );
    return id == null ? null : _annotations[id];
  }

  static InheritedProperties _annotationHighlight(
    InheritedProperties resolving,
    Color color,
  ) => resolving.copyWith<TextStyleBackground>(
    value: TextStyleBackground(CssColor.value(color)),
  );

  static InheritedProperties _annotationRecognizer(
    InheritedProperties resolving,
    GestureRecognizer recognizer,
  ) => resolving.copyWith<GestureRecognizer>(value: recognizer);

  void _applyTextIndent(BuildTree tree) {
    if (removeParagraphIndent ||
        tree.isInline != false ||
        tree.children.any((child) => child.isInline == false) ||
        tree.element.attributes.containsKey(
          HtmlConstants.startsMidBlockAttribute,
        ) ||
        tree.element.attributes.containsKey(
          HtmlConstants.textIndentAttribute,
        )) {
      return;
    }

    final indent = _effectiveTextIndent(tree);
    if (indent == null || !indent.isPositive) return;

    tree.element.attributes[HtmlConstants.textIndentAttribute] = '';
    tree.prepend(
      WidgetBit.inline(
        tree,
        WidgetPlaceholder(
          builder: (context, _) {
            final width = _resolveIndent(tree, indent, context);
            return width != null && width > 0
                ? SizedBox(width: width)
                : widget0;
          },
          debugLabel: '${tree.element.localName}--textIndent',
        ),
        alignment: .bottom,
      ),
    );
  }

  /// Returns the first valid `text-indent` declaration on [tree] or its
  /// ancestors. CSS inheritance applies to the block's first line.
  CssLength? _effectiveTextIndent(BuildTree tree) {
    for (BuildTree? current = tree; current != null;) {
      final parsed = _parseLength(current.getStyle('text-indent')?.value);
      if (parsed != null) return parsed;

      current = current.hasParent ? current.parent : null;
    }

    return null;
  }

  double? _resolveIndent(
    BuildTree tree,
    CssLength indent,
    BuildContext context,
  ) {
    return indent.getValue(tree.inheritanceResolvers.resolve(context));
  }

  static CssLength? _parseLength(css.Expression? expression) =>
      switch (expression) {
        css.EmTerm(:final value) => CssLength(
          (value as num).toDouble(),
          .em,
        ),
        css.LengthTerm(:final value, :final unit) => switch (unit) {
          css.TokenKind.UNIT_LENGTH_PX => CssLength(
            (value as num).toDouble(),
          ),
          css.TokenKind.UNIT_LENGTH_PT => CssLength(
            (value as num).toDouble(),
            .pt,
          ),
          _ => null,
        },
        css.PercentageTerm(:final value) => CssLength(
          (value as num).toDouble(),
          .percentage,
        ),
        css.NumberTerm(:final number) when number == 0 => CssLength.zero,
        _ => null,
      };

  /// Adds [declaration] to an inline style attribute without dropping the
  /// element's own declarations.
  String _appendStyle(String? existing, String declaration) {
    final current = existing?.trim() ?? '';
    if (current.isEmpty) return declaration;
    final separator = current.endsWith(';') ? ' ' : '; ';
    return '$current$separator$declaration';
  }

  Size _fit(Size size) {
    if (size.isEmpty) return size;

    final widthLimit = viewport.width.isFinite ? viewport.width : size.width;
    final heightLimit = viewport.height.isFinite
        ? viewport.height
        : size.height;

    final scale = math.min(
      1.0,
      math.min(widthLimit / size.width, heightLimit / size.height),
    );

    return Size(size.width * scale, size.height * scale);
  }
}
