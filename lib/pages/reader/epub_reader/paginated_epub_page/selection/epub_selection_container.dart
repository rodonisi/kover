import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Orders side-by-side [EpubSubpageSelectionContainer]s in reading direction.
///
/// Flutter's default [SelectionArea] delegate always orders horizontal
/// selectables left-to-right. Wrapping side-by-side subpage views in this
/// container reverses the horizontal order in RTL mode so cross-subpage
/// selections follow reading order.
class EpubSubpagesSelectionContainer extends HookWidget {
  const new({super.key, required this.child});

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

final class _SubpagesSelectionDelegate(final TextDirection textDirection)
    extends StaticSelectionContainerDelegate {
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
  const new({super.key, required this.child});

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
