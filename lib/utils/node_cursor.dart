import 'package:html/dom.dart';

/// Iterates through the children of the given node, filling a clone of the root every time the iterator is moved
/// forward
class NodeCursor {
  static final _leafTags = {'p', 'img', 'svg'};

  /// Shallow of the root provided during initialization
  final Element root;

  /// Iterator over the children of the root provided during initialization
  final Iterator<Node> iterator;

  Node? reprocess;

  /// Recursive child cursor if a child requires splitting
  NodeCursor? childCursor;

  bool get exhausted => _exhausted;

  bool _exhausted = false;

  bool get _isLeaf =>
      root.localName != null && _leafTags.contains(root.localName);

  NodeCursor({
    required Element root,
  }) : root = root.clone(false),
       iterator = root.nodes.iterator;

  /// Moves the iterator forward and adds the element to the root node. Returns the root node as filled so far.
  Node? next() {
    if (_exhausted || _isLeaf) {
      return null;
    }

    final childNode = childCursor?.next();
    if (childNode != null) {
      if (root.children.isEmpty) {
        root.append(childNode);
      } else {
        root.children.last.replaceWith(childNode);
      }
      return root;
    }

    childCursor = null;

    if (reprocess != null) {
      root.append(reprocess!);
      reprocess = null;
      return root;
    }

    if (!iterator.moveNext()) {
      _exhausted = true;
      return null;
    }

    root.append(iterator.current.clone(true));
    return root;
  }

  /// Return the root node up to and not including the current iterator position. The root children are cleared and the
  /// next page is started.
  Node commitSplit() {
    final childSplit = childCursor?.commitSplit();

    if (childSplit != null) {
      // Partial content fit inside the child — keep it in this subpage.
      root.children.last.replaceWith(childSplit);
    } else if (root.children.length > 1) {
      reprocess = root.children.removeLast();
    }

    final committed = root.clone(true);

    root.children.clear();

    return committed;
  }

  /// Tries to split the current cursor position. If a split happened already for this page, false is returned.
  bool splitChild() {
    if (_isLeaf || _exhausted) {
      return false;
    }

    if (childCursor != null) {
      return childCursor!.splitChild();
    }

    final current = iterator.current;
    if (_canSplit(current)) {
      childCursor = NodeCursor(root: current as Element);

      return true;
    }

    return false;
  }

  static bool _canSplit(Node node) {
    if (node is Element) {
      return node.localName != null && !_leafTags.contains(node.localName);
    }

    return false;
  }
}
