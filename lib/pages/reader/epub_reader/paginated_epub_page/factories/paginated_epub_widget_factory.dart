import 'dart:math' as math;

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_anchor_target.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/widgets/util/link_hit_region.dart';

/// A [WidgetFactory] that adjusts rendering for paginated EPUB content.
class PaginatedEpubWidgetFactory({
  final Size viewport = const Size(double.infinity, double.infinity),
  final bool removeParagraphIndent = false,
  final void Function(EpubAnchorTarget)? onAnchorTap,
}) extends WidgetFactory {
  late final BuildOp _textIndentOp = BuildOp(
    alwaysRenderBlock: false,
    debugLabel: 'epub-text-indent',
    onParsed: (tree) {
      _applyTextIndent(tree);
      return tree;
    },
  );

  @override
  void parse(BuildTree meta) {
    meta.register(_textIndentOp);

    super.parse(meta);
  }

  @override
  GestureRecognizer? buildGestureRecognizer(
    BuildTree tree, {
    GestureTapCallback? onTap,
  }) {
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
    if (built == null || onAnchorTap == null) return built;

    if (EpubAnchorTarget.fromElement(tree.element) == null) return built;

    return LinkHitRegion(child: built);
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
