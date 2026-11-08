import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/pagination/epub_subpage.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:kover/utils/logging.dart';

/// Splits an EPUB document into subpages based on the measured positions of
/// lines and blocks.
class EpubPaginator({required final dom.DocumentFragment root}) {
  final List<EpubSubpage> _subpages = [];
  final Map<int, String> _subpageHtml = {};
  final Map<int, String?> _scrollIds = {};

  int get subpageCount => _subpages.length;

  /// Splits the measured [units] into subpages of height [pageHeight].
  void paginate(
    List<EpubMeasureUnit> units,
    double pageHeight,
  ) {
    _subpages.clear();
    _subpageHtml.clear();
    _scrollIds.clear();

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

    EpubPosition? start;
    var startsMidBlock = false;
    var cursor = 0;

    while (cursor < units.length) {
      final origin = cursor == 0 ? 0.0 : units[cursor].pageStartTop;
      final limit = origin + pageHeight;

      var last = cursor;
      while (last + 1 < units.length && units[last + 1].pageEndBottom < limit) {
        last++;
      }

      final next = last + 1;
      final end = next < units.length ? units[next].start : null;

      _subpages.add(
        EpubSubpage(
          start: start,
          end: end,
          startsMidBlock: startsMidBlock,
        ),
      );

      if (next >= units.length) break;

      start = end;
      startsMidBlock = units[last].nodeIndex == units[next].nodeIndex;
      cursor = next;
    }
  }

  /// Returns the first subpage whose markup contains [scrollId].
  int? subpageForScrollId(String scrollId) {
    for (var index = 0; index < subpageCount; index++) {
      final fragment = dom.DocumentFragment.html(getSubpage(index));
      if (fragment.findByAttribute(HtmlConstants.scrollIdAttribute, scrollId) !=
          null) {
        return index;
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

  /// Clears serialized subpage HTML while keeping the pagination geometry.
  ///
  /// Call this after mutating attributes or classes on the document so the
  /// next render reflects the new markup.
  void invalidateSubpageCache() {
    _subpageHtml.clear();
  }

  /// Returns the serialized HTML of the subpage at [index], or an empty string
  /// if [index] is out of bounds.
  String getSubpage(int index) {
    if (index < 0 || index >= subpageCount) return '';

    if (_subpageHtml.containsKey(index)) {
      return _subpageHtml[index]!;
    }

    final subpage = _splitSubpage(_subpages[index]).outerHtml;
    _subpageHtml[index] = subpage;

    return subpage;
  }

  dom.DocumentFragment _splitSubpage(EpubSubpage page) {
    final subpage = root.clone(true);
    final start = page.start;
    final end = page.end;

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

    if (page.startsMidBlock) {
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

  /// Resolves a position to a node in [root].
  dom.Node? _nodeAt(dom.DocumentFragment root, EpubPosition position) {
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

  dom.Element? _blockAt(dom.DocumentFragment root, int nodeIndex) {
    return root.querySelector(
      '[${HtmlConstants.nodeIndexAttribute}="$nodeIndex"]',
    );
  }

  /// Removes everything belonging to the pages before [position].
  void _trimBefore(dom.Node root, dom.Node node, EpubPosition position) {
    var inclusive = position.afterNode;

    if (node is dom.Text && !position.afterNode) {
      final data = node.data;
      if (position.offset <= 0) {
        inclusive = false;
      } else if (position.offset < data.length) {
        node.data = data.substring(position.offset);
        inclusive = false;
      } else {
        // The position sits after the whole text node, so the node belongs to
        // the previous page.
        inclusive = true;
      }
    }

    _removeBefore(root, node, inclusive: inclusive);
  }

  /// Removes everything belonging to the pages after [position].
  void _trimAfter(dom.Node root, dom.Node node, EpubPosition position) {
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
