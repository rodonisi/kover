import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/factories/measuring_paginated_epub_widget_factory.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_block_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_leaf_probe.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_measure_anchor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_text_index.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_text_probe.dart';
import 'package:material_ui/material_ui.dart';

/// One page boundary. Points at a position inside the source tree.
///
/// [blockNodeIndex] is a preorder element index (see [epubNodeIndexAttribute]).
/// [childPath] addresses the node under that element using `childNodes`
/// indices. An empty [childPath] points at the start of the block itself.
class EpubBreak {
  final int blockNodeIndex;
  final List<int> childPath;
  final int offset;

  /// When true the break sits after the referenced node (used for `<br>`).
  final bool afterNode;

  const new({
    required this.blockNodeIndex,
    this.childPath = const [],
    this.offset = 0,
    this.afterNode = false,
  });

  @override
  bool operator ==(Object other) =>
      other is EpubBreak &&
      other.blockNodeIndex == blockNodeIndex &&
      other.offset == offset &&
      other.afterNode == afterNode &&
      listEquals(other.childPath, childPath);

  @override
  int get hashCode =>
      Object.hash(blockNodeIndex, Object.hashAll(childPath), offset, afterNode);
}

/// A single break unit produced by the measurement pass.
sealed class const EpubBreakUnit({
  /// Boundary that starts the page containing this unit.
  required final EpubBreak start,

  /// Source element index this unit belongs to.
  required final int nodeIndex,

  /// Top position of the unit in the viewport.
  required final double top,

  /// Bottom position of the unit in the viewport.
  required final double bottom,
}) {
  double get height => bottom - top;
}

/// A line of text. [start] points at the first character of the line.
final class const EpubLineUnit({
  required super.start,
  required super.nodeIndex,
  required super.top,
  required super.bottom,
}) extends EpubBreakUnit;

/// Content that cannot be split: image, table, rule, empty block...
final class const EpubLeafUnit({
  required super.start,
  required super.nodeIndex,
  required super.top,
  required super.bottom,
}) extends EpubBreakUnit;

class EpubMeasurements({
  required final List<EpubBreakUnit> units,
  required final Size contentSize,
});

class EpubMeasurementsCollector extends HookWidget {
  final dom.DocumentFragment html;
  final BoxConstraints constraints;
  final void Function(EpubMeasurements) onMeasured;
  const new({
    super.key,
    required this.html,
    required this.constraints,
    required this.onMeasured,
  });

  @override
  Widget build(BuildContext context) {
    final measureKey = useMemoized(() => GlobalKey());
    final scheduled = useRef(false);

    useEffect(() {
      if (scheduled.value) return;
      scheduled.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (!context.mounted) return;

          final anchor = measureKey.currentContext?.findRenderObject();
          if (anchor is! RenderEpubMeasureAnchor || !anchor.hasSize) return;

          onMeasured(collectMeasurements(anchor));
        } finally {
          scheduled.value = false;
        }
      });

      return null;
    }, [measureKey, html, constraints]);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ExcludeSemantics(
        child: EpubMeasureAnchor(
          key: measureKey,
          child: HtmlWidget(
            html.outerHtml,
            buildAsync: false,
            factoryBuilder: () => MeasuringPaginatedEpubWidgetFactory(
              viewport: Size(
                constraints.maxWidth,
                constraints.maxHeight,
              ),
            ),
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
  final stats = _HarvestStats();

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
          _emitTextUnits(
            probes: textProbes,
            origin: anchor,
            blockElements: blockElements,
            stats: stats,
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

class _HarvestStats {
  int textProbes = 0;
  int paragraphs = 0;
  int indexFailures = 0;
  String? firstFailure;
}

String _snippet(String text) {
  final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return singleLine.length <= 80
      ? singleLine
      : '${singleLine.substring(0, 80)}…';
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
    if (current is RenderEpubTextProbe ||
        current is RenderEpubLeafProbe ||
        current is RenderEpubBlockProbe) {
      found = true;
      return;
    }
    current.visitChildren(walk);
  }

  node.visitChildren(walk);
  return found;
}

List<EpubBreakUnit> _emitTextUnits({
  required List<RenderEpubTextProbe> probes,
  required RenderBox origin,
  required Set<dom.Element> blockElements,
  required _HarvestStats stats,
}) {
  final units = <EpubBreakUnit>[];

  for (final probe in probes) {
    stats.textProbes++;
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
      stats.paragraphs++;
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
      } on EpubTextIndexMismatch catch (error) {
        stats.indexFailures++;
        stats.firstFailure ??=
            '<${probe.element.localName}> ${error.reason} '
            'in "${_snippet(plainText)}"';
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

  return EpubLeafUnit(
    start: EpubBreak(blockNodeIndex: probe.nodeIndex),
    nodeIndex: probe.nodeIndex,
    top: topLeft.dy,
    bottom: topLeft.dy + box.size.height,
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

  final lines = <_LineBox>[];
  for (final box in sorted) {
    if (lines.isNotEmpty && (box.top - lines.last.top).abs() < 0.5) {
      final last = lines.removeLast();
      lines.add(
        _LineBox(
          top: last.top,
          bottom: box.bottom > last.bottom ? box.bottom : last.bottom,
        ),
      );
    } else {
      lines.add(_LineBox(top: box.top, bottom: box.bottom));
    }
  }

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

EpubLeafUnit? leafUnit({
  required int nodeIndex,
  required RenderBox box,
  required RenderBox origin,
}) {
  if (!box.attached || !box.hasSize) return null;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: origin);

  return EpubLeafUnit(
    start: EpubBreak(blockNodeIndex: nodeIndex),
    nodeIndex: nodeIndex,
    top: topLeft.dy,
    bottom: topLeft.dy + box.size.height,
  );
}
