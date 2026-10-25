import 'package:html/dom.dart' as dom;
import 'package:kover/utils/html_constants.dart';
import 'package:material_ui/material_ui.dart';

/// A text block of an epub page covered by the selection: the scroll id of
/// its element, the subpage showing it and the selected range as offsets
/// into the block's rendered text.
typedef SelectedBlock = ({String scrollId, int subpage, int start, int end});

/// Tracks which text blocks of an epub page the selection covers.
///
/// The blocks shown under an [EpubSelectionScope] register here through
/// [EpubSelectionBlock].
class EpubSelectionTracker {
  /// The elements of the page with a scroll id, in document order, and the
  /// position of each scroll id among them.
  final List<dom.Element> _elements;
  final Map<String, int> _order = {};
  final _blocks = <_Block>{};

  EpubSelectionTracker({required dom.DocumentFragment root})
    : _elements = root.querySelectorAll(
        '[${HtmlConstants.scrollIdAttribute}]',
      ) {
    for (final (index, element) in _elements.indexed) {
      _order[element.attributes[HtmlConstants.scrollIdAttribute]!] = index;
    }
  }

  /// The element of the page with [scrollId].
  dom.Element? elementOf(String scrollId) {
    final index = _order[scrollId];
    return index == null ? null : _elements[index];
  }

  /// The innermost blocks the selection covers, in reading order.
  List<SelectedBlock> get selectedBlocks {
    final covered = [
      for (final block in _blocks)
        if (block.notifier.registered &&
            block.notifier.selection.status == .uncollapsed)
          if (block.notifier.selection.range case final range?)
            (
              scrollId: block.scrollId,
              subpage: block.subpage,
              start: range.startOffset < range.endOffset
                  ? range.startOffset
                  : range.endOffset,
              end: range.startOffset < range.endOffset
                  ? range.endOffset
                  : range.startOffset,
            ),
    ];

    // A covered block inside another one is the more precise of the two.
    bool contains(SelectedBlock outer, SelectedBlock inner) =>
        outer.subpage == inner.subpage &&
        inner.scrollId.startsWith('${outer.scrollId}/');
    final innermost = covered
        .where((block) => !covered.any((other) => contains(block, other)))
        .toList();

    int position(SelectedBlock block) => _order[block.scrollId] ?? -1;
    return innermost..sort(
      (a, b) => a.subpage != b.subpage
          ? a.subpage.compareTo(b.subpage)
          : position(a).compareTo(position(b)),
    );
  }

  void _add(_Block block) => _blocks.add(block);

  void _remove(_Block block) => _blocks.remove(block);
}

class _Block {
  final String scrollId;
  final int subpage;
  final SelectionListenerNotifier notifier;

  _Block({
    required this.scrollId,
    required this.subpage,
    required this.notifier,
  });
}

/// Provides the [EpubSelectionTracker] of the page to the blocks of one of
/// its subpages.
class EpubSelectionScope extends InheritedWidget {
  final EpubSelectionTracker tracker;
  final int subpage;

  const EpubSelectionScope({
    super.key,
    required this.tracker,
    required this.subpage,
    required super.child,
  });

  static EpubSelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EpubSelectionScope>();

  @override
  bool updateShouldNotify(EpubSelectionScope oldWidget) =>
      tracker != oldWidget.tracker || subpage != oldWidget.subpage;
}

/// Reports the selection over the block element with [scrollId] to the
/// tracker of the enclosing [EpubSelectionScope]. Without a scope, e.g. when
/// measuring, it only shows [child].
class EpubSelectionBlock extends StatefulWidget {
  final String scrollId;
  final Widget child;

  const EpubSelectionBlock({
    super.key,
    required this.scrollId,
    required this.child,
  });

  @override
  State<EpubSelectionBlock> createState() => _EpubSelectionBlockState();
}

class _EpubSelectionBlockState extends State<EpubSelectionBlock> {
  SelectionListenerNotifier? _notifier;
  EpubSelectionScope? _scope;
  _Block? _block;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(EpubSelectionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollId != widget.scrollId) _register();
  }

  void _register() {
    final scope = EpubSelectionScope.maybeOf(context);
    if (_block case final block?) _scope?.tracker._remove(block);

    _scope = scope;
    if (scope == null) {
      _block = null;
      return;
    }

    final block = _Block(
      scrollId: widget.scrollId,
      subpage: scope.subpage,
      notifier: _notifier ??= SelectionListenerNotifier(),
    );
    _block = block;
    scope.tracker._add(block);
  }

  @override
  void dispose() {
    if (_block case final block?) _scope?.tracker._remove(block);
    _notifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = _notifier;
    if (_scope == null || notifier == null) return widget.child;

    return SelectionListener(selectionNotifier: notifier, child: widget.child);
  }
}
