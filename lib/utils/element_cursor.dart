import 'package:html/dom.dart';

class ElementCursor {
  static const Set<String> _leafTags = {'img', 'svg'};

  final Element _root;
  final Element _buffer;
  final List<Object> _stack = [];
  final List<Element> _targetStack = [];
  late Element _target;

  ElementCursor({required Element root})
    : _root = root.clone(true),
      _buffer = root.clone(false) {
    _stack.addAll(_root.nodes.reversed);
    _targetStack.add(_buffer);
    _target = _buffer;
  }

  Element? addNext() {
    if (_stack.isEmpty) return null;

    final node = _stack.removeLast();

    switch (node) {
      case _PopMarker():
        _targetStack.removeLast();
        _target = _targetStack.last;
        return addNext();
      case _CommitBacktrack(:final innerNode):
        _target.append(innerNode);
        return _stack.length > 1 ? addNext() : _buffer;
      case Node _:
        _target.append(node);
        return _buffer;
      default:
        throw Exception('Unexpected stack item: $node');
    }
  }

  Element commitSplit() {
    if (_target.nodes.isNotEmpty) {
      _stack.add(_CommitBacktrack(_target.nodes.removeLast()));
    }

    final result = _buffer.clone(true);

    // Reconstruct a clear tree up to the current target
    _targetStack.fold(null, (Element? parent, current) {
      current.nodes.clear();
      if (parent != null) parent.append(current);
      return current;
    });

    return result;
  }

  bool splitChild() {
    if (_target.nodes.isEmpty) return false;

    final child = _target.nodes.last;

    if (child is Text) {
      return _splitTextNode(child);
    }

    if (child is! Element ||
        _leafTags.contains(child.localName) ||
        child.nodes.isEmpty) {
      return false;
    }

    final newTarget = child.clone(false);
    _target.nodes.last.replaceWith(newTarget);

    // Push a marker so we know when this element's children are done
    _stack.add(_PopMarker());
    _stack.addAll(child.nodes.reversed);

    _target = newTarget;
    _targetStack.add(newTarget);

    return true;
  }

  bool _splitTextNode(Text child) {
    final text = child.text;

    // Split by sentences, keeping the delimiters and trailing whitespaces.
    final sentencesReg = RegExp(r'.*?[.!?]+(?:\s+|$)|.+?$');

    final sentences = sentencesReg
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();

    if (sentences.length > 1) {
      child.remove();

      for (final sentence in sentences.reversed) {
        _stack.add(Text(sentence));
      }

      return true;
    }

    // Split by words, keeping the whitespace (Regex keeps the delimiters)
    // This captures words and the spaces following them.
    final words = text.split(RegExp(r'(?<=\s)'));

    if (words.length <= 1) {
      // If it's only one word and it still doesn't fit,
      // we can't split it further by word.
      return false;
    }

    child.remove();

    for (final word in words.reversed) {
      _stack.add(Text(word));
    }

    return true;
  }
}

/// Simple marker indicating we need to pop the target stack
class _PopMarker {}

/// Simple wrapper for a node was popped from the target following a split.
/// A node can only be popped on commit once to avoid endless loops.
class _CommitBacktrack {
  final Node innerNode;
  _CommitBacktrack(this.innerNode);
}
