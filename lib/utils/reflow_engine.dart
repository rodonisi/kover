import 'package:html/dom.dart';
import 'package:kover/utils/html_constants.dart';

abstract class ReflowEngine {
  /// The current buffer element that is being built.
  Element get buffer;

  /// The progress of the reflow operation, as a value between 0.0 and 1.0.
  double get progress;

  /// Adds the next node from the source tree to the buffer.
  /// Returns true when a node was added, false if there are no more nodes to add.
  bool addNext();

  /// Splits the last child of the current target element, if possible.
  /// Returns true if a split was performed, false otherwise.
  bool splitChild();

  /// Commits the current buffer and returns a new buffer for further additions.
  Element commitSplit();
}

const Set<String> _leafTags = {'img', 'svg'};

final _sentencesReg = RegExp(r'.*?[.!?]+(?:\s+|$)|.+?$');
final _wordsReg = RegExp(r'(?=\s)');

/// Splits [text] into words. The whitespace leads the following word, so a
/// page-ending word is measured without its trailing whitespace while no
/// whitespace is lost. Returns null when the text is a single word.
List<String>? _wordSegments(String text) {
  final words = text.split(_wordsReg).where((word) => word.isNotEmpty).toList();

  return words.length > 1 ? words : null;
}

/// Splits [text] into sentences, or into words when it is a single sentence.
/// Returns null when the text cannot be split further.
List<String>? _textSegments(String text) {
  // Split by sentences, keeping the delimiters and trailing whitespaces.
  final sentences = _sentencesReg
      .allMatches(text)
      .map((match) => match.group(0)!)
      .toList();

  if (sentences.length > 1) return sentences;

  return _wordSegments(text);
}

class LinearReflowEngine implements ReflowEngine {
  final Element _root;
  final Element _buffer;
  final List<Object> _stack = [];
  final List<Element> _targetStack = [];
  late Element _target;
  int _consumed = 0;

  LinearReflowEngine({required Element root})
    : _root = root.clone(true),
      _buffer = root.clone(false) {
    _stack.addAll(_root.nodes.reversed);
    _targetStack.add(_buffer);
    _target = _buffer;
  }

  @override
  Element get buffer => _buffer;

  @override
  double get progress {
    final total = _consumed + _stack.length;
    if (total == 0) return 1.0;
    return _consumed / total;
  }

  @override
  bool addNext() {
    if (_stack.isEmpty) return false;

    final node = _stack.removeLast();
    _consumed++;

    switch (node) {
      case _PopMarker():
        _targetStack.removeLast();
        _target = _targetStack.last;
        return addNext();
      case _CommitBacktrack(:final innerNode):
        _target.append(innerNode);
        return _stack.length > 1 ? addNext() : true;
      case Node _:
        _target.append(node);
        return true;
      default:
        throw Exception('Unexpected stack item: $node');
    }
  }

  @override
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

  @override
  bool splitChild() {
    if (_target.nodes.isEmpty) return false;

    final child = _target.nodes.last;

    if (child is Text) {
      return _splitTextNode(child);
    }

    if (child is! Element ||
        _leafTags.contains(child.localName) ||
        child.nodes.isEmpty ||
        child.attributes.containsKey(HtmlConstants.textIndentSpanAttribute)) {
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
    final segments = _textSegments(child.text);

    // A single word that still doesn't fit can't be split further.
    if (segments == null) return false;

    child.remove();

    for (final segment in segments.reversed) {
      _stack.add(Text(segment));
    }

    return true;
  }
}

/// Binary search reflow engine. Each tree level is probed by binary search
/// on the number of child units that fit. When the boundary unit is found,
/// the engine descends one level and binary searches within it, until the
/// unit is unsplittable (same end condition as [LinearReflowEngine]).
///
/// The driver contract matches [ReflowEngine]: [addNext] reports that the
/// current buffer fits, [splitChild] reports that it overflows.
class BinaryReflowEngine implements ReflowEngine {
  final Element _root;
  final Element _buffer;
  final List<_Frame> _frames = [];

  /// Child count of the root at construction, for [progress].
  final int _rootUnits;

  BinaryReflowEngine({required Element root})
    : _root = root.clone(true),
      _buffer = root.clone(false),
      _rootUnits = root.nodes.length {
    _frames.add(_Frame(target: _buffer, pending: List.of(_root.nodes)));
  }

  @override
  Element get buffer => _buffer;

  @override
  double get progress {
    if (_frames.isEmpty || _rootUnits == 0) return 1.0;

    return (1 - _frames.first.pending.length / _rootUnits).clamp(0.0, 1.0);
  }

  @override
  bool addNext() {
    if (_frames.isEmpty) return false;

    final frame = _frames.last;

    // Level exhausted: pop and continue the parent level.
    if (frame.pending.isEmpty) {
      _frames.removeLast();
      return addNext();
    }

    // The current probe fits.
    frame.lo = frame.p;

    if (frame.p == frame.pending.length) {
      // The whole level fits: pop. The parent resumes past the straddler
      // slot, which permanently shows the child shell from now on.
      _frames.removeLast();
      if (_frames.isEmpty) return false;

      final parent = _frames.last;
      final slot = parent.splitAt!;
      parent.pending[slot] = frame.target;
      parent.splitAt = null;
      parent.lo = slot + 1;
      parent.hi = parent.pending.length;
      parent.p = parent.lo + ((parent.hi - parent.lo + 1) >> 1);
      _rebuild(parent);
      return true;
    }

    // Probe the upper half of the remaining range. When the range collapsed
    // (hi == lo + 1) this re-appends the known overflower so the driver
    // reports overflow and the boundary handling kicks in.
    frame.p = frame.lo + ((frame.hi - frame.lo + 1) >> 1);
    _rebuild(frame);
    return true;
  }

  @override
  bool splitChild() {
    if (_frames.isEmpty) return false;

    final frame = _frames.last;
    if (frame.p == 0) return false;

    frame.hi = frame.p;

    // Range not collapsed: shrink the probe to the midpoint.
    if (frame.hi - frame.lo > 1) {
      frame.p = (frame.lo + frame.hi) >> 1;
      _rebuild(frame);
      return true;
    }

    // Boundary found: pending[lo] is the overflower. Descend.
    final unit = frame.pending[frame.lo];

    if (unit is Text) {
      final segments = _textSegments(unit.text);
      if (segments == null) return false;

      frame.pending
        ..removeAt(frame.lo)
        ..insertAll(frame.lo, segments.map(Text.new));
      frame.hi = frame.lo + segments.length;
      frame.p = frame.lo;
      _rebuild(frame);
      return true;
    }

    if (unit is! Element ||
        _leafTags.contains(unit.localName) ||
        unit.nodes.isEmpty ||
        unit.attributes.containsKey(HtmlConstants.textIndentSpanAttribute)) {
      return false;
    }

    // Descend one level: swap the tree node for an empty shell clone. The
    // unit itself stays untouched in pending until the child level pops.
    final shell = unit.clone(false);
    frame.target.nodes.last.replaceWith(shell);
    frame.splitAt = frame.lo;
    _frames.add(_Frame(target: shell, pending: List.of(unit.nodes)));

    return true;
  }

  @override
  Element commitSplit() {
    final frame = _frames.last;

    // Backtrack the overflower so it resumes on the next page.
    if (frame.target.nodes.isNotEmpty) {
      frame.target.nodes.removeLast();
    }
    frame.pending.removeRange(0, frame.lo);

    // Ancestors committed everything before the straddler unit. The unit
    // itself stays (hollow) so the child shell swap keeps its slot.
    for (var i = 0; i < _frames.length - 1; i++) {
      final f = _frames[i];
      f.pending.removeRange(0, f.splitAt!);
      f.splitAt = 0;
    }

    final result = _buffer.clone(true);

    // Reconstruct a clear tree up to the deepest target.
    Element? parent;
    for (final f in _frames) {
      f.target.nodes.clear();
      if (parent != null) parent.append(f.target);
      parent = f.target;
    }

    // The fresh page re-measures everything: reset the bounds.
    for (final f in _frames) {
      f.p = 0;
      f.lo = 0;
      f.hi = f.pending.length;
    }

    return result;
  }

  /// Mirrors the first [_Frame.p] units of [frame] into its target.
  void _rebuild(_Frame frame) {
    frame.target.nodes
      ..clear()
      ..addAll(frame.pending.take(frame.p));
  }
}

/// One binary search level: the units of a single target element.
class _Frame {
  _Frame({required this.target, required this.pending}) : hi = pending.length;

  /// The element in the buffer tree units are mirrored into.
  final Element target;

  /// The units of this level; the first [p] are mirrored into [target].
  final List<Node> pending;

  /// Units currently mirrored into [target].
  int p = 0;

  /// Units confirmed by the driver to fit.
  int lo = 0;

  /// Units reported by the driver to overflow; [pending.length] while
  /// unknown.
  int hi;

  /// Index of the straddler unit a child frame descended into, if any.
  int? splitAt;
}

/// Simple marker indicating we need to pop the target stack
class _PopMarker {}

/// Simple wrapper for a node was popped from the target following a split.
/// A node can only be popped on commit once to avoid endless loops.
class _CommitBacktrack {
  final Node innerNode;
  _CommitBacktrack(this.innerNode);
}
