import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:html/dom.dart';
import 'package:kover/models/font_face.dart';

/// Extracts `@font-face` declarations from epub page CSS.
class EpubFontParser {
  const EpubFontParser._();

  /// Parses every `<style>` tag in [styles] and returns the declared font
  /// faces in source order.
  static List<FontFace> parseStyles(Iterable<Element> styles) {
    return [for (final element in styles) ...parseCss(element.innerHtml)];
  }

  /// Parses [cssString] and returns the declared font faces in source order.
  static List<FontFace> parseCss(String cssString) {
    final sheet = css.parse(cssString);
    final visitor = _FontFaceVisitor();
    sheet.visit(visitor);
    return visitor.faces;
  }
}

class _FontFaceVisitor extends Visitor {
  static const _supportedFormats = {'ttf', 'otf'};

  final List<FontFace> faces = [];

  String? _currentFamily;
  int? _currentWeight;
  List<String> _currentUrls = [];

  @override
  void visitFontFaceDirective(FontFaceDirective node) {
    _currentFamily = null;
    _currentWeight = null;
    _currentUrls = [];

    super.visitFontFaceDirective(node);

    final family = _currentFamily;
    if (family != null) {
      for (final url in _currentUrls) {
        faces.add(
          FontFace(family: family, weight: _currentWeight, url: url),
        );
      }
    }
  }

  @override
  void visitDeclaration(Declaration node) {
    final property = node.property.toLowerCase();

    final expr = node.expression;
    if (expr == null) return;

    switch (property) {
      case 'font-family':
        final term = expr is Expressions ? expr.expressions.firstOrNull : expr;
        if (term is LiteralTerm) {
          final v = term.value;
          _currentFamily = v is Identifier ? v.name : _unquote('$v');
        }
      case 'font-weight':
        _currentWeight = _extractWeight(expr);
      case 'src':
        _currentUrls = _extractUrls(expr);
    }

    super.visitDeclaration(node);
  }

  int? _extractWeight(Expression expr) {
    final term = expr is Expressions ? expr.expressions.firstOrNull : expr;
    if (term is! LiteralTerm) return null;

    final v = term.value;
    if (v is Identifier) {
      return switch (v.name.toLowerCase()) {
        'bold' => 700,
        _ => null,
      };
    }

    return int.tryParse('$v');
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        (value.startsWith("'") && value.endsWith("'") ||
            value.startsWith('"') && value.endsWith('"'))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  List<String> _extractUrls(Expression expr) {
    if (expr is! Expressions) return [];
    return expr.expressions
        .whereType<UriTerm>()
        .map((t) => t.value as String)
        .where((url) {
          final ext = url.split('.').last.toLowerCase();
          return _supportedFormats.contains(ext);
        })
        .toList();
  }
}
