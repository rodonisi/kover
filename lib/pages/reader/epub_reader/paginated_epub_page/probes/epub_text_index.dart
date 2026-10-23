import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/utils/html_constants.dart';

/// A position inside the DOM that corresponds to a character of the flattened
/// inline text.
class EpubTextPosition {
  const EpubTextPosition({
    required this.node,
    required this.offset,
    this.afterNode = false,
  });

  final dom.Node node;
  final int offset;
  final bool afterNode;
}

/// Thrown when the flattened text of a block cannot be mapped back to its DOM
/// nodes.
class EpubTextIndexMismatch implements Exception {
  const EpubTextIndexMismatch(this.reason);

  final String reason;

  @override
  String toString() => 'EpubTextIndexMismatch: $reason';
}

/// Aligns the flattened inline text of [block] (the text fwfh puts into a
/// single `RichText`) with its DOM nodes, so line start offsets can be turned
/// back into DOM break points.
///
/// The alignment is greedy: whitespace runs in the DOM may collapse or vanish,
/// so a normalized space consumes a raw whitespace run and a non-space
/// character skips collapsed whitespace before matching. Inline widgets
/// injected by fwfh (indent spans, anchors, inline-block elements, sup/sub,
/// horizontal margins/padding) are represented by `U+FFFC` in the flattened
/// text and are consumed as single tokens. Anything that does not line up
/// throws [EpubTextIndexMismatch]; the caller then treats the block as
/// unsplittable.
class EpubTextIndex {
  EpubTextIndex._(this._positions);

  final List<EpubTextPosition> _positions;

  /// Returns the DOM position of the visible character at [offset].
  EpubTextPosition? positionAt(int offset) {
    if (offset < 0 || offset >= _positions.length) return null;
    return _positions[offset];
  }

  static EpubTextIndex build({
    required dom.Element block,
    required Set<dom.Element> blockElements,
    required CssWhitespace whitespace,
    required String plainText,
  }) {
    final tokens = <_Token>[];
    _collect(
      block: block,
      node: block,
      blockElements: blockElements,
      whitespace: whitespace,
      tokens: tokens,
    );

    final positions = <EpubTextPosition>[];
    var index = 0;

    for (var i = 0; i < plainText.length; i++) {
      final char = plainText[i];
      final isNewline = char == '\n';
      final isPlaceholder = char == '\uFFFC';
      final isSpace = char == ' ' || char == '\u00A0';

      if (isPlaceholder) {
        while (_peek(tokens, index) is _WhitespaceToken) {
          index++;
        }
        final token = _peek(tokens, index);
        if (token is! _InlineToken) {
          throw EpubTextIndexMismatch('expected inline widget at $i');
        }
        positions.add(EpubTextPosition(node: token.element, offset: 0));
        index++;
        continue;
      }

      if (isNewline) {
        while (_peek(tokens, index) is _WhitespaceToken) {
          index++;
        }
        final token = _peek(tokens, index);
        if (token is _BreakToken) {
          positions.add(
            EpubTextPosition(
              node: token.element,
              offset: 0,
              afterNode: true,
            ),
          );
          index++;
          continue;
        }
        if (whitespace != CssWhitespace.pre) {
          throw EpubTextIndexMismatch('expected <br> at $i');
        }
      }

      if (whitespace == CssWhitespace.pre) {
        final token = _peek(tokens, index);
        if (token is! _CharToken || token.char != char) {
          throw EpubTextIndexMismatch('pre text mismatch at $i');
        }
        positions.add(EpubTextPosition(node: token.node, offset: token.offset));
        index++;
        continue;
      }

      if (isSpace) {
        final token = _peek(tokens, index);
        if (token is _WhitespaceToken) {
          positions.add(
            EpubTextPosition(node: token.node, offset: token.offset),
          );
          index++;
          continue;
        }
        if (token is _CharToken &&
            (token.char == ' ' || token.char == '\u00A0')) {
          positions.add(
            EpubTextPosition(node: token.node, offset: token.offset),
          );
          index++;
          continue;
        }
        throw EpubTextIndexMismatch('expected whitespace at $i');
      }

      while (true) {
        final token = _peek(tokens, index);
        if (token is _WhitespaceToken) {
          index++;
          continue;
        }
        break;
      }

      final token = _peek(tokens, index);
      if (token is! _CharToken || token.char != char) {
        throw EpubTextIndexMismatch('expected "$char" at $i');
      }
      positions.add(EpubTextPosition(node: token.node, offset: token.offset));
      index++;
    }

    for (var i = index; i < tokens.length; i++) {
      final token = tokens[i];
      if (token is _WhitespaceToken ||
          token is _BreakToken ||
          token is _InlineToken) {
        continue;
      }
      throw const EpubTextIndexMismatch('trailing content after text');
    }

    return EpubTextIndex._(positions);
  }
}

_Token? _peek(List<_Token> tokens, int index) =>
    index < tokens.length ? tokens[index] : null;

void _collect({
  required dom.Element block,
  required dom.Node node,
  required Set<dom.Element> blockElements,
  required CssWhitespace whitespace,
  required List<_Token> tokens,
}) {
  if (node is dom.Text) {
    final data = node.data;
    if (whitespace == CssWhitespace.pre) {
      for (var i = 0; i < data.length; i++) {
        tokens.add(_CharToken(node: node, offset: i, char: data[i]));
      }
      return;
    }

    var i = 0;
    while (i < data.length) {
      final char = data[i];
      if (_isWhitespace(char)) {
        final start = i;
        while (i < data.length && _isWhitespace(data[i])) {
          i++;
        }
        tokens.add(_WhitespaceToken(node: node, offset: start));
        continue;
      }

      tokens.add(_CharToken(node: node, offset: i, char: char));
      i++;
    }
    return;
  }

  if (node is! dom.Element) return;

  final localName = node.localName;
  if (localName == 'br') {
    tokens.add(_BreakToken(node));
    return;
  }

  if (node.attributes.containsKey(HtmlConstants.textIndentSpanAttribute)) {
    tokens.add(_InlineToken(node));
    return;
  }

  if (localName == 'sup' ||
      localName == 'sub' ||
      _hasInlineBlockDisplay(node)) {
    if (node.attributes.containsKey('id')) tokens.add(_InlineToken(node));
    tokens.add(_InlineToken(node));
    return;
  }

  if (localName != null && _inlineWidgetTags.contains(localName)) {
    tokens.add(_InlineToken(node));
    if (node.attributes.containsKey('id')) tokens.add(_InlineToken(node));
    return;
  }

  // Inline elements with an id get an extra anchor placeholder from fwfh.
  if (node.attributes.containsKey('id') && !blockElements.contains(node)) {
    tokens.add(_InlineToken(node));
  }

  final isInline = !blockElements.contains(node);
  if (isInline) {
    if (_hasInlineHorizontalSpace(node, 'margin', 'left')) {
      tokens.add(_InlineToken(node));
    }
    if (_hasInlineHorizontalSpace(node, 'padding', 'left')) {
      tokens.add(_InlineToken(node));
    }
  }

  for (final child in node.nodes) {
    final isNestedBlock =
        child is dom.Element &&
        !identical(child, block) &&
        blockElements.contains(child) &&
        !_isInlineWidgetElement(child);
    if (isNestedBlock) continue;
    _collect(
      block: block,
      node: child,
      blockElements: blockElements,
      whitespace: whitespace,
      tokens: tokens,
    );
  }

  if (isInline) {
    if (_hasInlineHorizontalSpace(node, 'padding', 'right')) {
      tokens.add(_InlineToken(node));
    }
    if (_hasInlineHorizontalSpace(node, 'margin', 'right')) {
      tokens.add(_InlineToken(node));
    }
  }
}

bool _hasInlineHorizontalSpace(
  dom.Element element,
  String property,
  String side,
) {
  for (final style in element.styles) {
    if (style.property == '$property-$side' || style.property == property) {
      return true;
    }
  }
  return false;
}

bool _hasInlineBlockDisplay(dom.Element element) {
  final style = element.attributes['style'];
  if (style == null) return false;
  return RegExp(
    r'display\s*:\s*inline-block',
    caseSensitive: false,
  ).hasMatch(style);
}

bool _isInlineWidgetElement(dom.Element element) {
  final localName = element.localName;
  return element.attributes.containsKey(
        HtmlConstants.textIndentSpanAttribute,
      ) ||
      localName == 'sup' ||
      localName == 'sub' ||
      (localName != null && _inlineWidgetTags.contains(localName)) ||
      _hasInlineBlockDisplay(element);
}

const _inlineWidgetTags = {
  'img',
  'svg',
  'video',
  'audio',
  'canvas',
  'iframe',
  'object',
  'embed',
};

bool _isWhitespace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r' || char == '\f';

sealed class _Token {
  const _Token();
}

final class _CharToken extends _Token {
  const _CharToken({
    required this.node,
    required this.offset,
    required this.char,
  });

  final dom.Text node;
  final int offset;
  final String char;
}

final class _WhitespaceToken extends _Token {
  const _WhitespaceToken({required this.node, required this.offset});

  final dom.Text node;
  final int offset;
}

final class _BreakToken extends _Token {
  const _BreakToken(this.element);

  final dom.Element element;
}

final class _InlineToken extends _Token {
  const _InlineToken(this.element);

  final dom.Element element;
}
