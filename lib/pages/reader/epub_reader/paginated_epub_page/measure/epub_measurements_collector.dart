import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/measuring_paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_anchor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_text_index.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/render_html.dart';
import 'package:material_ui/material_ui.dart';

class const EpubMeasurements({
  required final List<EpubBreakUnit> units,
  required final Size contentSize,
});

class EpubMeasurementsCollector extends HookWidget {
  final dom.DocumentFragment html;
  final Size viewport;
  final void Function(EpubMeasurements) onMeasured;
  const new({
    super.key,
    required this.html,
    required this.viewport,
    required this.onMeasured,
  });

  @override
  Widget build(BuildContext context) {
    final measureKey = useMemoized(() => GlobalKey());
    final scheduled = useRef(false);
    final factoryRef = useRef<MeasuringPaginatedEpubWidgetFactory?>(null);

    void scheduleMeasurement() {
      if (scheduled.value) return;
      scheduled.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (!context.mounted) return;
          final factory = factoryRef.value;
          if (factory == null || factory.pendingImages > 0) return;
          if (html.outerHtml.isNotEmpty && !factory.isBuildComplete) return;

          final anchor = measureKey.currentContext?.findRenderObject();
          if (anchor is! RenderEpubMeasureAnchor || !anchor.hasSize) return;

          final measurements = collectMeasurements(anchor);

          if (measurements.contentSize.height > 0 &&
              measurements.units.isEmpty) {
            scheduled.value = false;
            scheduleMeasurement();
            return;
          }

          onMeasured(measurements);
        } finally {
          scheduled.value = false;
        }
      });
    }

    final factory = useMemoized(() {
      final created = MeasuringPaginatedEpubWidgetFactory(
        viewport: viewport,
        onBuildComplete: scheduleMeasurement,
        onImageSettled: scheduleMeasurement,
      );
      factoryRef.value = created;
      return created;
    }, [html, viewport]);

    useEffect(() {
      scheduleMeasurement();
      return null;
    }, [measureKey, html, viewport, factory]);

    if (viewport.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ExcludeSemantics(
        child: EpubMeasureAnchor(
          key: measureKey,
          child: RenderHtml(
            key: ValueKey(viewport),
            html: html.outerHtml,
            factoryBuilder: () => factory,
          ),
        ),
      ),
    );
  }
}

/// Walks every probe injected by [MeasuringPaginatedEpubWidgetFactory] and
/// turns it into break units, ordered by the render tree.
EpubMeasurements collectMeasurements(RenderEpubMeasureAnchor anchor) {
  final units = <EpubBreakUnit>[];
  final blockElements = <dom.Element>{};

  // Text probes are grouped by their nearest block, so nested block elements
  // must be known before line boxes are mapped back to DOM positions.
  void collectBlocks(RenderObject node) {
    if (node is RenderEpubBlockProbe) {
      blockElements.add(node.element);
    }
    node.visitChildren(collectBlocks);
  }

  collectBlocks(anchor);

  void walk(RenderObject node) {
    // Text probes are emitted by their owning block below.
    if (node is RenderEpubTextProbe) return;

    if (node is RenderEpubLeafProbe) {
      final unit = leafUnit(
        nodeIndex: node.nodeIndex,
        box: node,
        origin: anchor,
      );
      if (unit != null) units.add(unit);
      return;
    }

    if (node is RenderEpubBlockProbe) {
      final textProbes = _collectOwnTextProbes(node);

      if (textProbes.isNotEmpty) {
        units.addAll(
          _collectTextUnits(
            probes: textProbes,
            origin: anchor,
            blockElements: blockElements,
          ),
        );
      } else if (!_hasProbeDescendant(node)) {
        // A block without any probe below it cannot be split (image, rule,
        // empty block...).
        final unit = leafUnit(
          nodeIndex: node.nodeIndex,
          box: node,
          origin: anchor,
        );
        if (unit != null) units.add(unit);
        return;
      }

      // Wrapper blocks have no text probes of their own; keep walking so the
      // paragraph blocks inside them are harvested too.
      node.visitChildren(walk);
      return;
    }

    node.visitChildren(walk);
  }

  walk(anchor);

  return EpubMeasurements(units: units, contentSize: anchor.size);
}

List<RenderEpubTextProbe> _collectOwnTextProbes(RenderObject block) {
  final probes = <RenderEpubTextProbe>[];

  void walk(RenderObject node) {
    if (node is RenderEpubBlockProbe || node is RenderEpubLeafProbe) return;
    if (node is RenderEpubTextProbe) {
      probes.add(node);
      return;
    }
    node.visitChildren(walk);
  }

  block.visitChildren(walk);

  return probes;
}

bool _hasProbeDescendant(RenderObject node) {
  var found = false;

  void walk(RenderObject current) {
    if (found) return;
    if (current is RenderEpubProbe) {
      found = true;
      return;
    }
    current.visitChildren(walk);
  }

  node.visitChildren(walk);
  return found;
}

List<EpubBreakUnit> _collectTextUnits({
  required List<RenderEpubTextProbe> probes,
  required RenderBox origin,
  required Set<dom.Element> blockElements,
}) {
  final units = <EpubBreakUnit>[];

  for (final probe in probes) {
    if (!probe.attached || !probe.hasSize) continue;

    final paragraphs = <RenderParagraph>[];
    void findParagraphs(RenderObject node) {
      if (node is RenderParagraph) {
        paragraphs.add(node);
        return;
      }
      node.visitChildren(findParagraphs);
    }

    probe.visitChildren(findParagraphs);

    for (final paragraph in paragraphs) {
      if (!paragraph.attached || !paragraph.hasSize) continue;

      final plainText = paragraph.text.toPlainText();
      if (plainText.isEmpty) continue;

      EpubTextIndex index;
      try {
        index = EpubTextIndex.build(
          block: probe.element,
          blockElements: blockElements,
          whitespace: probe.whitespace,
          plainText: plainText,
        );
      } on EpubTextIndexMismatch catch (_) {
        // List markers and partial inline content do not map to the block's
        // DOM text; keep them as one unsplittable unit instead of dropping
        // the measurement.
        final fallback = _textLeafUnit(
          probe: probe,
          box: paragraph,
          origin: origin,
        );
        if (fallback != null) units.add(fallback);
        continue;
      }

      final paragraphOrigin = paragraph.localToGlobal(
        Offset.zero,
        ancestor: origin,
      );

      final lines = _lineBoxes(paragraph, plainText);
      final padding = _paddingInsets(paragraph, origin);
      final firstLineTop = lines.first.top;
      final trailingBottom = paragraph.size.height > lines.last.bottom
          ? paragraph.size.height - lines.last.bottom
          : 0.0;
      var emitted = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final startOffset = _lineStartOffset(paragraph, line);
        final position = index.positionAt(startOffset);
        if (position == null) continue;

        final isLast = i == lines.length - 1;
        final bottom = isLast
            ? paragraphOrigin.dy +
                  (line.bottom > paragraph.size.height
                      ? line.bottom
                      : paragraph.size.height)
            : paragraphOrigin.dy + line.bottom;

        units.add(
          EpubLineUnit(
            start: EpubBreak(
              blockNodeIndex: probe.nodeIndex,
              childPath: _childPathOf(probe.element, position.node),
              offset: position.offset,
              afterNode: position.afterNode,
            ),
            nodeIndex: probe.nodeIndex,
            top: paragraphOrigin.dy + line.top,
            bottom: bottom,
            topInset: padding.top + firstLineTop,
            bottomInset: padding.bottom + (isLast ? 0.0 : trailingBottom),
          ),
        );
        emitted++;
      }

      if (emitted == 0) {
        final fallback = _textLeafUnit(
          probe: probe,
          box: paragraph,
          origin: origin,
        );
        if (fallback != null) units.add(fallback);
      }
    }
  }

  return units;
}

EpubLeafUnit? _textLeafUnit({
  required RenderEpubTextProbe probe,
  required RenderBox box,
  required RenderBox origin,
}) {
  if (!box.attached || !box.hasSize) return null;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: origin);
  final padding = _paddingInsets(box, origin);

  return EpubLeafUnit(
    start: EpubBreak(blockNodeIndex: probe.nodeIndex),
    nodeIndex: probe.nodeIndex,
    top: topLeft.dy,
    bottom: topLeft.dy + box.size.height,
    topInset: padding.top,
    bottomInset: padding.bottom,
  );
}

class _LineBox {
  const _LineBox({required this.top, required this.bottom});

  final double top;
  final double bottom;
}

List<_LineBox> _lineBoxes(RenderParagraph paragraph, String plainText) {
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: plainText.length),
    boxHeightStyle: .includeLineSpacingMiddle,
    boxWidthStyle: .max,
  );

  if (boxes.isEmpty) {
    return [_LineBox(top: 0, bottom: paragraph.size.height)];
  }

  final sorted = boxes.toList()..sort((a, b) => a.top.compareTo(b.top));

  final lines = [
    for (final box in sorted) _LineBox(top: box.top, bottom: box.bottom),
  ];

  return lines;
}

int _lineStartOffset(RenderParagraph paragraph, _LineBox line) {
  final width = paragraph.size.width;
  final x = paragraph.textDirection == .rtl
      ? (width - 0.1).clamp(0.0, width)
      : 0.1;

  final position = paragraph.getPositionForOffset(
    Offset(x, (line.top + line.bottom) / 2),
  );

  return position.offset;
}

List<int> _childPathOf(dom.Element block, dom.Node node) {
  final path = <int>[];
  dom.Node? current = node;

  while (current != null && !identical(current, block)) {
    final parent = current.parent;
    if (parent == null) return const [];
    final index = parent.nodes.indexOf(current);
    if (index < 0) return const [];
    path.insert(0, index);
    current = parent;
  }

  return path;
}

({double top, double bottom}) _paddingInsets(
  RenderObject node,
  RenderObject origin,
) {
  var top = 0.0;
  var bottom = 0.0;
  RenderObject? current = node.parent;

  while (current != null && !identical(current, origin)) {
    if (current is RenderEpubPaddingProbe) {
      top += current.padding.top;
      bottom += current.padding.bottom;
    }
    current = current.parent;
  }

  return (top: top, bottom: bottom);
}

EpubLeafUnit? leafUnit({
  required int nodeIndex,
  required RenderBox box,
  required RenderBox origin,
}) {
  if (!box.attached || !box.hasSize) return null;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: origin);
  final padding = _paddingInsets(box, origin);

  return EpubLeafUnit(
    start: EpubBreak(blockNodeIndex: nodeIndex),
    nodeIndex: nodeIndex,
    top: topLeft.dy,
    bottom: topLeft.dy + box.size.height,
    topInset: padding.top,
    bottomInset: padding.bottom,
  );
}
