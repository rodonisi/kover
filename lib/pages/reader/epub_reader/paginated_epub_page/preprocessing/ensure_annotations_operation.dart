import 'dart:math' as math;

import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/logging.dart';

/// Injects highlights for annotations that are not present in the page markup.
///
/// The operation follows the page walk and only keeps state for elements that
/// match an annotation xpath. Text is buffered between the start and end
/// element of every annotation, then matched against the annotation's selected
/// text once the walk is complete.
final class EnsureAnnotationsOperation extends EpubPagePreprocessorOperation {
  EnsureAnnotationsOperation({
    required Iterable<PaginatedEpubAnnotation> annotations,
  }) : _annotations = annotations.toList(growable: false);

  final List<PaginatedEpubAnnotation> _annotations;

  final _byServerId = <int, PaginatedEpubAnnotation>{};
  final _byStartXPath = <String, List<PaginatedEpubAnnotation>>{};
  final _byEndXPath = <String, List<PaginatedEpubAnnotation>>{};
  final _present = <int>{};
  final _startElements = <int, dom.Element>{};
  final _endElements = <int, dom.Element>{};
  final _buffers = <int, _TextBuffer>{};
  final _active = <PaginatedEpubAnnotation>{};
  final _startOrder = <int, int>{};
  final _covered = <dom.Text, List<_Span>>{};

  var _nextStartOrder = 0;
  var _noWrapDepth = 0;

  @override
  void start(dom.DocumentFragment root) {
    _byServerId.clear();
    _byStartXPath.clear();
    _byEndXPath.clear();
    _present.clear();
    _startElements.clear();
    _endElements.clear();
    _buffers.clear();
    _active.clear();
    _startOrder.clear();
    _covered.clear();
    _nextStartOrder = 0;
    _noWrapDepth = 0;

    for (final annotation in _annotations) {
      if (annotation.serverId case final serverId?) {
        _byServerId[serverId] = annotation;
      }

      final xpath = annotation.xpath;
      final endXpath = annotation.endXpath;

      if (xpath.isNotEmpty) {
        _byStartXPath.putIfAbsent(xpath, () => []).add(annotation);
      }

      if (endXpath.isNotEmpty) {
        _byEndXPath.putIfAbsent(endXpath, () => []).add(annotation);
      }
    }
  }

  @override
  void enter(dom.Element element) {
    final localName = element.localName;

    if (localName == 'script' || localName == 'style') {
      _noWrapDepth++;
    }

    if (localName == HtmlConstants.kavitaHighlightElementTag) {
      _adopt(element);
      return;
    }

    final scrollId = element.attributes[HtmlConstants.scrollIdAttribute];
    if (scrollId == null) return;

    for (final annotation in _byStartXPath[scrollId] ?? const []) {
      _startElements.putIfAbsent(annotation.id, () => element);
      _startOrder.putIfAbsent(annotation.id, () => _nextStartOrder++);
      _active.add(annotation);
    }

    for (final annotation in _byEndXPath[scrollId] ?? const []) {
      _endElements.putIfAbsent(annotation.id, () => element);
    }
  }

  @override
  void exit(dom.Element element) {
    final localName = element.localName;

    if (localName != HtmlConstants.kavitaHighlightElementTag) {
      final scrollId = element.attributes[HtmlConstants.scrollIdAttribute];
      for (final annotation in _byEndXPath[scrollId] ?? const []) {
        _active.remove(annotation);
      }
    }

    if (localName == 'script' || localName == 'style') {
      _noWrapDepth--;
    }
  }

  @override
  void text(dom.Text text) {
    if (_noWrapDepth > 0 || _active.isEmpty) return;

    final block = _blockElement(text);
    for (final annotation in _active) {
      final buffer = _buffers.putIfAbsent(annotation.id, _TextBuffer.new);
      if (buffer.lastBlock != null &&
          block != null &&
          !identical(buffer.lastBlock, block)) {
        buffer.addSeparator();
      }

      buffer.add(text);
      buffer.lastBlock = block;
    }
  }

  @override
  void finish(dom.DocumentFragment root) {
    final missing =
        _annotations
            .where(
              (annotation) =>
                  !_present.contains(annotation.id) &&
                  _startElements.containsKey(annotation.id) &&
                  _endElements.containsKey(annotation.id),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => (_startOrder[a.id] ?? 1 << 30).compareTo(
              _startOrder[b.id] ?? 1 << 30,
            ),
          );

    for (final annotation in missing) {
      _collectSpans(annotation);
    }

    for (final entry in _covered.entries) {
      _wrap(entry.key, entry.value);
    }
  }

  void _adopt(dom.Element element) {
    final serverId = HtmlConstants.annotationServerId(element.attributes);
    if (serverId == null) return;

    final annotation = _byServerId[serverId];
    if (annotation == null) return;

    element.attributes[HtmlConstants.koverAnnotationIdAttribute] =
        '${annotation.id}';
    _present.add(annotation.id);
  }

  void _collectSpans(PaginatedEpubAnnotation annotation) {
    final buffer = _buffers[annotation.id];
    final selectedText = annotation.selectedText;

    if (buffer == null || buffer.runs.isEmpty || selectedText.trim().isEmpty) {
      return;
    }

    final match = buffer.match(selectedText);
    if (match == null) {
      log.debug(
        'annotation text not found',
        attributes: {
          'annotation_id': annotation.id,
          'xpath': annotation.xpath,
          'end_xpath': annotation.endXpath,
          'text': _head(selectedText),
          'page_text': _head(buffer.text.toString()),
        },
      );
      return;
    }

    for (final run in buffer.runs) {
      final start = math.max(match.start, run.start);
      final end = math.min(match.end, run.end);
      if (end <= start) continue;
      if (_insideHighlight(run.node)) continue;

      final localStart = start - run.start;
      final localEnd = end - run.start;
      for (final segment in _subtract(
        run.node,
        localStart,
        localEnd,
      )) {
        _covered
            .putIfAbsent(run.node, () => [])
            .add(
              _Span(
                annotation: annotation,
                start: segment.$1,
                end: segment.$2,
              ),
            );
      }
    }
  }

  Iterable<(int, int)> _subtract(dom.Text node, int start, int end) sync* {
    var segments = <(int, int)>[(start, end)];
    for (final span in _covered[node] ?? const <_Span>[]) {
      final next = <(int, int)>[];
      for (final segment in segments) {
        if (span.end <= segment.$1 || span.start >= segment.$2) {
          next.add(segment);
          continue;
        }
        if (span.start > segment.$1) next.add((segment.$1, span.start));
        if (span.end < segment.$2) next.add((span.end, segment.$2));
      }
      segments = next;
    }

    yield* segments;
  }

  static void _wrap(dom.Text node, List<_Span> spans) {
    final parent = node.parent;
    if (parent == null) return;

    spans.sort((a, b) => a.start.compareTo(b.start));
    final text = node.data;
    final inserts = <dom.Node>[];
    var cursor = 0;

    for (final span in spans) {
      final start = math.max(span.start, cursor).clamp(0, text.length).toInt();
      final end = span.end.clamp(0, text.length).toInt();
      if (end <= start) continue;

      if (start > cursor) {
        inserts.add(dom.Text(text.substring(cursor, start)));
      }

      final highlight =
          dom.Element.tag(
              HtmlConstants.kavitaHighlightElementTag,
            )
            ..attributes[HtmlConstants.koverAnnotationIdAttribute] =
                '${span.annotation.id}';

      if (span.annotation.serverId case final serverId?) {
        highlight.attributes[HtmlConstants.kavitaAnnotationIdAttribute] =
            '$serverId';
      }

      highlight.append(dom.Text(text.substring(start, end)));
      inserts.add(highlight);
      cursor = end;
    }

    if (inserts.isEmpty) return;

    if (cursor < text.length) {
      inserts.add(dom.Text(text.substring(cursor)));
    }

    for (final insert in inserts) {
      parent.insertBefore(insert, node);
    }

    node.remove();
  }

  static bool _insideHighlight(dom.Text node) {
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent.localName == HtmlConstants.kavitaHighlightElementTag) {
        return true;
      }
    }

    return false;
  }

  static dom.Element? _blockElement(dom.Text node) {
    dom.Element? current = node.parent;
    while (current != null && _inlineTags.contains(current.localName)) {
      current = current.parent;
    }

    return current;
  }

  static String _head(String text) =>
      text.length <= 120 ? text : '${text.substring(0, 120)}…';

  static const _inlineTags = {
    'em',
    'strong',
    'i',
    'b',
    'span',
    'a',
    'cite',
    'sup',
    'sub',
    'small',
    'mark',
    'code',
    'kbd',
    'samp',
    'var',
    'q',
    'abbr',
    'dfn',
    'u',
    's',
    'del',
    'ins',
    'strike',
    'font',
    'big',
    'tt',
    'nobr',
    'ruby',
    'rt',
    'rp',
    'bdi',
    'bdo',
    'time',
    'label',
    HtmlConstants.kavitaHighlightElementTag,
  };
}

final class _TextBuffer {
  final text = StringBuffer();
  final runs = <_TextRun>[];
  dom.Element? lastBlock;

  void add(dom.Text node) {
    runs.add(_TextRun(node: node, start: text.length));
    text.write(node.data);
  }

  void addSeparator() => text.write('\n\n');

  _Match? match(String selectedText) {
    final raw = text.toString();
    final normalized = _normalize(raw);
    final selection = _normalize(selectedText).text;
    if (selection.isEmpty) return null;

    final index = normalized.text.indexOf(selection);
    if (index < 0) return null;

    return _Match(
      start: normalized.starts[index],
      end: normalized.starts[index + selection.length],
    );
  }
}

final class _TextRun {
  const _TextRun({required this.node, required this.start});

  final dom.Text node;
  final int start;

  int get end => start + node.data.length;
}

final class _Span {
  _Span({required this.annotation, required this.start, required this.end});

  final PaginatedEpubAnnotation annotation;
  final int start;
  final int end;
}

final class _Match {
  const _Match({required this.start, required this.end});

  /// Offsets in the raw, unnormalized buffered text.
  final int start;
  final int end;
}

final class _Normalized {
  const _Normalized({required this.text, required this.starts});

  final String text;

  /// Raw offset of every normalized character, plus the end boundary.
  final List<int> starts;
}

/// Collapses whitespace runs to one space and trims the result, while keeping
/// a map from normalized characters back to the raw text.
_Normalized _normalize(String value) {
  final chars = <String>[];
  final starts = <int>[];
  var pendingSpaceStart = -1;

  for (var index = 0; index < value.length; index++) {
    final char = value[index];

    if (_isWhitespace(char)) {
      pendingSpaceStart = pendingSpaceStart < 0 ? index : pendingSpaceStart;
      continue;
    }

    if (pendingSpaceStart >= 0 && chars.isNotEmpty) {
      chars.add(' ');
      starts.add(pendingSpaceStart);
    }
    pendingSpaceStart = -1;

    chars.add(char);
    starts.add(index);
  }

  starts.add(value.length);
  return _Normalized(text: chars.join(), starts: starts);
}

bool _isWhitespace(String char) =>
    char == ' ' ||
    char == '\t' ||
    char == '\n' ||
    char == '\r' ||
    char == '\f' ||
    char == '\u00A0';
