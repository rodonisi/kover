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
      final previous = selected[index - 1].block;
      final current = selected[index].block;
      final sameElement = current.nodeIndex == previous.nodeIndex;
      final separator = switch (sameElement) {
        false => '\n\n',
        true when _hasBoundaryWhitespace(previous, current) => ' ',
        true => '',
      };
      selectedText
        ..write(separator)
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

  static bool _hasBoundaryWhitespace(_Block before, _Block after) {
    final beforeText = before.element.textContent(convertBRsToNewlines: true);
    final afterText = after.element.textContent(convertBRsToNewlines: true);
    final beforeHasWhitespace =
        beforeText != null &&
        beforeText.isNotEmpty &&
        _whitespace.hasMatch(beforeText[beforeText.length - 1]);
    final afterHasWhitespace =
        afterText != null &&
        afterText.isNotEmpty &&
        _whitespace.hasMatch(afterText[0]);

    return beforeHasWhitespace || afterHasWhitespace;
  }

  static final _whitespace = RegExp(r'\s+');
}

/// Registers the text rendered for [element] with [registry].
///
/// Blocks nested in another block, such as superscripts, are not registered:
/// their text already belongs to the outer block.
class EpubSelectableBlock extends HookWidget {
  const new({
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

final class _Block._({
  required final dom.Element element,
  required final StaticSelectionContainerDelegate delegate,
  required final String xPath,

  /// The position of [element] in the document.
  required final int nodeIndex,

  /// The subpage on which this block is rendered.
  required final int subpageIndex,
}) implements Comparable<_Block> {
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
