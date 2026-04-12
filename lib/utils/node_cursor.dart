import 'package:html/dom.dart';
import 'package:kover/utils/logging.dart';

/// Iterates through the children of the given node, filling a clone of the root every time the iterator is moved
/// forward
class NodeCursor {
  /// Shallow of the root provided during initialization
  final Element root;

  /// Iterator over the children of the root provided during initialization
  final Iterator<Node> iterator;

  /// Recursive child cursor if a child requires splitting
  NodeCursor? childCursor;

  bool hasNext = true;

  NodeCursor({
    required Element root,
  }) : root = root.clone(false),
       iterator = root.nodes.iterator;

  /// Moves the iterator forward and adds the element to the root node. Returns the root node as filled so far.
  Node? next() {
    if (childCursor != null) {
      final childNext = childCursor!.next();
      if (childNext != null) {
        root.children.last.replaceWith(childNext);
        return root;
      }
      childCursor = null;
      return root;
    }

    if (!iterator.moveNext()) {
      hasNext = false;
      log.d(
        'iterator exhausted, hasNext=false, current root has ${root.children.length}',
      );
      if (root.children.isNotEmpty) {
        final lastChunk = root.clone(true);
        root.children.clear();
        return lastChunk;
      }
      return null;
    }

    root.append(iterator.current.clone(true));
    return root;
  }

  /// Returns whether the current iterator position can be split. This is the case if the current node is an element
  /// with children that would result in a non-empty page after splitting.
  bool canSplit() {
    // If we are splitting inside a child, we can split only if:
    // 1) there is already something before the current top-level node, or
    // 2) the child itself can split.
    if (childCursor != null) {
      return root.children.length > 1 || childCursor!.canSplit();
    }

    // Split between siblings (before current node) if page already has previous content.
    if (root.children.length > 1) {
      return true;
    }

    if (!hasNext) {
      return false;
    }

    // Otherwise we can split only inside current node.
    final current = iterator.current;
    return current is Element &&
        current.localName != 'p' &&
        current.children.isNotEmpty;
  }

  /// Return the root node up to and not including the current iterator position. The root children are cleared and the
  /// next page is started.
  Node split() {
    if (childCursor != null && root.children.isNotEmpty) {
      root.children.last.replaceWith(childCursor!.split());
      if (childCursor != null && !childCursor!.hasNext) {
        childCursor = null;
      }
    } else {
      if (childCursor != null) {
        // childCursor exists but root is empty, discard inconsistent child
        childCursor = null;
      }
      if (root.children.isNotEmpty) {
        root.children.removeLast();
      }
    }

    final subpage = root.clone(true);
    root.children.clear();

    if (hasNext) {
      root.append(iterator.current.clone(true));
    }

    return subpage;
  }

  /// Tries to split the current cursor position. If a split happened already for this page, false is returned.
  bool splitChild() {
    if (childCursor != null) {
      return childCursor!.splitChild();
    }

    if (!hasNext) return false;

    final current = iterator.current;
    if (current is Element &&
        current.localName != 'p' &&
        current.children.isNotEmpty) {
      childCursor = NodeCursor(root: current);

      return true;
    }

    return false;
  }
}
