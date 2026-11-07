import 'package:html/dom.dart' as dom;
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break_unit.dart';
import 'package:kover/utils/logging.dart';

/// Splits an EPUB document into subpages based on the measured positions of
/// lines and blocks.
class EpubPaginator({required final dom.DocumentFragment root}) {
  final List<EpubBreak> _breaks = [];
  final Map<int, String> _subpages = {};
  final Map<int, int> _nodePages = {};
  final Map<int, String?> _scrollIds = {};
  bool _hasMeasurement = false;

  /// The document always has a first page, so there is one more subpage than
  /// there are breaks.
  int get subpageCount => _hasMeasurement ? _breaks.length + 1 : 0;

  void paginate(
    List<EpubBreakUnit> units,
    double pageHeight,
  ) {
    _breaks.clear();
    _subpages.clear();
    _nodePages.clear();
    _scrollIds.clear();
    _hasMeasurement = true;

    if (units.isEmpty || pageHeight <= 0) {
      log.debug(
        'Skipping pagination',
        attributes: {
          'units': units.length,
          'pageHeight': pageHeight,
        },
      );
      return;
    }

    final starts = <EpubBreak>[];
    var cursor = 0;
    var pageIndex = 0;

    while (cursor < units.length) {
      final origin = cursor == 0 ? 0.0 : units[cursor].pageStartTop;
      final limit = origin + pageHeight;

      var last = cursor;
      while (last + 1 < units.length &&
          units[last + 1].pageEndBottom <= limit) {
        last++;
      }

      for (var index = cursor; index <= last; index++) {
        _nodePages.putIfAbsent(units[index].nodeIndex, () => pageIndex);
      }

      final next = last + 1;
      if (next >= units.length) break;

      starts.add(
        units[next].start.copyWith(
          startsMidBlock: units[last].nodeIndex == units[next].nodeIndex,
        ),
      );
      cursor = next;
      pageIndex++;
    }

    _breaks.addAll(starts);
  }

  /// Returns the subpage that contains the start of [nodeIndex], if known.
  int? subpageForNodeIndex(int nodeIndex) => _nodePages[nodeIndex];

  /// Returns the first subpage whose markup contains [scrollId].
  ///
  /// This is used as a fallback when the resume element cannot be mapped to a
  /// block node index.
  int? subpageForScrollId(String scrollId) {
    for (var index = 0; index < subpageCount; index++) {
      final fragment = dom.DocumentFragment.html(getSubpage(index));
      final elements = fragment.querySelectorAll(
        '[${HtmlConstants.scrollIdAttribute}]',
      );
      for (final element in elements) {
        if (element.attributes[HtmlConstants.scrollIdAttribute] == scrollId) {
          return index;
        }
      }
    }

    return null;
  }

  /// Returns the scroll id of the first paragraph on [index], if any.
  String? scrollIdForSubpage(int index) {
    if (index < 0 || index >= subpageCount) return null;
    if (_scrollIds.containsKey(index)) return _scrollIds[index];

    final fragment = dom.DocumentFragment.html(getSubpage(index));
    String? scrollId;
    for (final paragraph in fragment.querySelectorAll('p')) {
      if (!paragraph.hasText) continue;
      scrollId = paragraph.attributes[HtmlConstants.scrollIdAttribute];
      break;
    }

    _scrollIds[index] = scrollId;
    return scrollId;
  }

  String getSubpage(int index) {
    if (index < 0 || index >= subpageCount) return '';

    if (_subpages.containsKey(index)) {
      return _subpages[index]!;
    }

    // The first page starts at the beginning of the document. Every other
    // page starts at the break that ended the previous page.
    final start = index == 0 ? null : _breaks[index - 1];
    final end = index < _breaks.length ? _breaks[index] : null;

    final subpage = _splitSubpage(start, end).outerHtml;
    _subpages[index] = subpage;

    return subpage;
  }

  dom.DocumentFragment _splitSubpage(EpubBreak? start, EpubBreak? end) {
    final subpage = root.clone(true);

    // Both boundaries are resolved before trimming: removing nodes invalidates
    // sibling positions in the cloned tree.
    final endNode = end == null ? null : _nodeAt(subpage, end);
    if (end != null && endNode == null) {
      log.debug(
        'End node not found for subpage',
        attributes: {'start': start, 'end': end},
      );
      return dom.DocumentFragment();
    }

    final startNode = start == null ? null : _nodeAt(subpage, start);
    if (start != null && startNode == null) {
      log.debug(
        'Start node not found for subpage',
        attributes: {'start': start, 'end': end},
      );
      return dom.DocumentFragment();
    }

    // Mark the page edges before trimming. The renderer drops the top margin
    // of everything on the first path and the bottom margin of everything on
    // the last path, so the rendered page matches the measured height (which
    // only carries padding and line leading).
    if (start != null) {
      final startBlock = _blockAt(subpage, start.blockNodeIndex);
      if (startBlock != null) {
        _markPath(startBlock, HtmlConstants.splitStartAttribute);
      }
    }

    if (end != null) {
      final endBlock = _blockAt(subpage, end.blockNodeIndex);
      if (endBlock != null) {
        _markPath(endBlock, HtmlConstants.splitEndAttribute);
      }
    }

    if (end != null) {
      _trimAfter(subpage, endNode!, end);
    }

    if (start != null) {
      _trimBefore(subpage, startNode!, start);
    }

    if (start?.startsMidBlock == true) {
      _blockAt(
        subpage,
        start!.blockNodeIndex,
      )?.attributes[HtmlConstants.splitParagraphAttribute] = '';
    }

    // Trimming can leave empty paragraph shells whose margins would still
    // contribute vertical space to the rendered page.
    subpage
        .querySelectorAll('p')
        .where((element) => !element.hasVisibleNodes)
        .toList()
        .forEach((element) => element.remove());

    return subpage;
  }

  void _markPath(dom.Element element, String attribute) {
    dom.Node? current = element;
    while (current is dom.Element) {
      current.attributes[attribute] = '';
      current = current.parent;
    }
  }

  /// Resolves a break to a node in [root].
  ///
  /// [EpubBreak.blockNodeIndex] is a preorder element index (see
  /// [HtmlConstants.nodeIndexAttribute]) and [EpubBreak.childPath] addresses a
  /// node below that element using `nodes` indices.
  dom.Node? _nodeAt(dom.Node root, EpubBreak position) {
    final block = _blockAt(root, position.blockNodeIndex);
    if (block == null) return null;

    dom.Node current = block;
    for (final index in position.childPath) {
      final nodes = current.nodes;
      if (index < 0 || index >= nodes.length) return null;
      current = nodes[index];
    }

    return current;
  }

  dom.Element? _blockAt(dom.Node root, int nodeIndex) {
    final attribute = HtmlConstants.nodeIndexAttribute;
    dom.Element? match;

    void visit(dom.Node node) {
      if (match != null) return;

      if (node is dom.Element) {
        final value = node.attributes[attribute];
        if (value != null && int.tryParse(value) == nodeIndex) {
          match = node;
          return;
        }
      }

      for (final child in node.nodes) {
        visit(child);
      }
    }

    visit(root);

    return match;
  }

  /// Removes everything belonging to the pages before [position].
  void _trimBefore(dom.Node root, dom.Node node, EpubBreak position) {
    var inclusive = position.afterNode;

    if (node is dom.Text && !position.afterNode) {
      final data = node.data;
      if (position.offset <= 0) {
        inclusive = false;
      } else if (position.offset < data.length) {
        node.data = data.substring(position.offset);
        inclusive = false;
      } else {
        // The break sits after the whole text node, so the node belongs to the
        // previous page.
        inclusive = true;
      }
    }

    _removeBefore(root, node, inclusive: inclusive);
  }

  /// Removes everything belonging to the pages after [position].
  void _trimAfter(dom.Node root, dom.Node node, EpubBreak position) {
    var inclusive = !position.afterNode && position.offset <= 0;

    if (node is dom.Text && !position.afterNode) {
      final data = node.data;
      if (position.offset > 0 && position.offset < data.length) {
        node.data = data.substring(0, position.offset);
        inclusive = false;
      } else if (position.offset >= data.length) {
        inclusive = false;
      }
    }

    _removeAfter(root, node, inclusive: inclusive);
  }

  /// Removes preceding siblings of [target] at every ancestor level, keeping
  /// the ancestors themselves. When [inclusive] is true [target] is removed
  /// as well.
  void _removeBefore(
    dom.Node root,
    dom.Node target, {
    required bool inclusive,
  }) {
    var current = target;
    var includeCurrent = inclusive;

    while (!identical(current, root)) {
      final parent = current.parentNode;
      if (parent == null) break;

      final siblings = parent.nodes;
      final index = siblings.indexOf(current);
      if (index < 0) break;

      siblings.removeRange(0, includeCurrent ? index + 1 : index);

      current = parent;
      includeCurrent = false;
    }
  }

  /// Removes following siblings of [target] at every ancestor level, keeping
  /// the ancestors themselves. When [inclusive] is true [target] is removed
  /// as well.
  void _removeAfter(
    dom.Node root,
    dom.Node target, {
    required bool inclusive,
  }) {
    var current = target;
    var includeCurrent = inclusive;

    while (!identical(current, root)) {
      final parent = current.parentNode;
      if (parent == null) break;

      final siblings = parent.nodes;
      final index = siblings.indexOf(current);
      if (index < 0) break;

      siblings.removeRange(includeCurrent ? index : index + 1, siblings.length);

      current = parent;
      includeCurrent = false;
    }
  }
}
