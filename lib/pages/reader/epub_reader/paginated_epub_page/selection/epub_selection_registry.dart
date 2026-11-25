import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/utils/constants/html_constants.dart';

/// Knows which rendered text blocks of a paginated EPUB page are selected.
///
/// Flutter reports a selection as one string without paragraph boundaries.
/// Every text block registers here through [EpubSelectableBlock], so the
/// selection can be read per HTML element instead.
final class EpubSelectionRegistry {
  final _blocks = <_Block>[];

  /// Builds an annotation draft from the current selection.
  ///
  /// Returns `null` when no text is selected.
  AnnotationDraft? resolveDraft() {
    final selected = [
      for (final block in _blocks)
        if (block.selectedText case final text?) (block: block, text: text),
    ]..sort((a, b) => a.block.compareTo(b.block));
    if (selected.isEmpty) return null;

    final selectedText = StringBuffer(selected.first.text);
    for (var index = 1; index < selected.length; index++) {
      // A paragraph split over two subpages is rendered as two blocks of the
      // same element. Kavita separates different elements by a blank line.
      final sameElement =
          selected[index].block.nodeIndex ==
          selected[index - 1].block.nodeIndex;
      selectedText
        ..write(sameElement ? ' ' : '\n\n')
        ..write(selected[index].text);
    }

    final end = selected.last.block;
    return AnnotationDraft(
      xPath: selected.first.block.xPath,
      endingXPath: end.xPath,
      selectedText: selectedText.toString(),
      context: end.element.text.replaceAll(_whitespace, ' ').trim(),
    );
  }

  static final _whitespace = RegExp(r'\s+');
}

/// Orders side-by-side [EpubSubpageSelectionContainer]s in reading direction.
///
/// Flutter's default [SelectionArea] delegate always orders horizontal
/// selectables left-to-right. Wrapping side-by-side subpage views in this
/// container reverses the horizontal order in RTL mode so cross-subpage
/// selections follow reading order.
class EpubSubpagesSelectionContainer extends HookWidget {
  const EpubSubpagesSelectionContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final delegate = useMemoized(
      () => _SubpagesSelectionDelegate(textDirection),
      [textDirection],
    );
    useEffect(() => delegate.dispose, [delegate]);

    return SelectionContainer(delegate: delegate, child: child);
  }
}

final class _SubpagesSelectionDelegate
    extends StaticSelectionContainerDelegate {
  _SubpagesSelectionDelegate(this.textDirection);

  final TextDirection textDirection;

  @override
  Comparator<Selectable> get compareOrder =>
      textDirection == .rtl ? _compareRtlScreenOrder : super.compareOrder;

  static int _compareRtlScreenOrder(Selectable a, Selectable b) {
    final rectA = MatrixUtils.transformRect(
      a.getTransformTo(null),
      Offset.zero & a.size,
    );
    final rectB = MatrixUtils.transformRect(
      b.getTransformTo(null),
      Offset.zero & b.size,
    );
    if (rectA.bottom <= rectB.top) return -1;
    if (rectB.bottom <= rectA.top) return 1;
    return rectB.right.compareTo(rectA.right);
  }
}

/// Keeps a text selection inside a subpage in reading order.
///
/// Flutter orders selectable text row by row across the whole selection area.
/// Subpages that are laid out next to each other share the same rows: the
/// columns of a spread, and the neighbours a page view keeps built off screen.
/// Their paragraphs would end up in between the selected ones. A subpage with
/// its own container is ordered as a whole instead.
class EpubSubpageSelectionContainer extends HookWidget {
  const EpubSubpageSelectionContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delegate = useMemoized(_SubpageSelectionDelegate.new);
    delegate.textDirection = Directionality.of(context);
    useEffect(() => delegate.dispose, [delegate]);

    return SelectionContainer(delegate: delegate, child: child);
  }
}

/// Treats a position beside the subpage as before or after all of its text.
///
/// Flutter asks every paragraph where a selection edge lies relative to it. A
/// position in a neighbouring subpage is level with some rows and below
/// others, and the subpage would claim the edge for itself.
final class _SubpageSelectionDelegate extends StaticSelectionContainerDelegate {
  TextDirection textDirection = .ltr;

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final bounds = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & containerSize,
    );
    final position = event.globalPosition;

    // Above the first row is before all text, below the last row after it.
    final isBefore = textDirection == .rtl
        ? position.dx >= bounds.right
        : position.dx < bounds.left;
    final isAfter = textDirection == .rtl
        ? position.dx < bounds.left
        : position.dx >= bounds.right;

    final Offset moved;
    if (isBefore) {
      moved = Offset(position.dx, bounds.top - 1);
    } else if (isAfter) {
      moved = Offset(position.dx, bounds.bottom + 1);
    } else {
      return super.handleSelectionEdgeUpdate(event);
    }

    return super.handleSelectionEdgeUpdate(
      event.type == .endEdgeUpdate
          ? .forEnd(globalPosition: moved, granularity: event.granularity)
          : .forStart(globalPosition: moved, granularity: event.granularity),
    );
  }
}

/// Registers the text rendered for [element] with [registry].
///
/// Blocks nested in another block, such as superscripts, are not registered:
/// their text already belongs to the outer block.
class EpubSelectableBlock extends HookWidget {
  const EpubSelectableBlock({
    super.key,
    required this.registry,
    required this.element,
    this.subpageIndex = 0,
    required this.child,
  });

  final EpubSelectionRegistry registry;
  final dom.Element element;
  final int subpageIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delegate = useMemoized(StaticSelectionContainerDelegate.new);
    useEffect(() => delegate.dispose, [delegate]);

    final isNested =
        context.findAncestorWidgetOfExactType<EpubSelectableBlock>() != null;
    final block = useMemoized(
      () => isNested ? null : _Block.tryCreate(element, delegate, subpageIndex),
      [element, delegate, isNested, subpageIndex],
    );

    useEffect(() {
      if (block == null) return null;

      registry._blocks.add(block);
      return () => registry._blocks.remove(block);
    }, [registry, block]);

    if (block == null) return child;

    return SelectionContainer(delegate: delegate, child: child);
  }
}

final class _Block implements Comparable<_Block> {
  _Block._({
    required this.element,
    required this.delegate,
    required this.xPath,
    required this.nodeIndex,
    required this.subpageIndex,
  });

  /// Returns `null` when [element] was not prepared by the page preprocessor.
  static _Block? tryCreate(
    dom.Element element,
    StaticSelectionContainerDelegate delegate,
    int subpageIndex,
  ) {
    final xPath = element.attributes[HtmlConstants.scrollIdAttribute];
    final nodeIndex = int.tryParse(
      element.attributes[HtmlConstants.nodeIndexAttribute] ?? '',
    );
    if (xPath == null || xPath.isEmpty || nodeIndex == null) return null;

    return _Block._(
      element: element,
      delegate: delegate,
      xPath: xPath,
      nodeIndex: nodeIndex,
      subpageIndex: subpageIndex,
    );
  }

  final dom.Element element;
  final StaticSelectionContainerDelegate delegate;
  final String xPath;

  /// The position of [element] in the document.
  final int nodeIndex;

  /// The subpage on which this block is rendered.
  final int subpageIndex;

  /// Whether this block renders the rest of a paragraph that started on the
  /// previous subpage.
  bool get startsMidBlock =>
      element.attributes.containsKey(HtmlConstants.startsMidBlockAttribute);

  String? get selectedText {
    final text = delegate.getSelectedContent()?.plainText.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Orders blocks by document position.
  @override
  int compareTo(_Block other) {
    final byElement = nodeIndex.compareTo(other.nodeIndex);
    if (byElement != 0) return byElement;

    final bySubpage = subpageIndex.compareTo(other.subpageIndex);
    if (bySubpage != 0) return bySubpage;

    if (startsMidBlock == other.startsMidBlock) return 0;

    return startsMidBlock ? 1 : -1;
  }
}
