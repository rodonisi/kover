import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';

/// Resolves the document stylesheet and an optional additional stylesheet to
/// concrete declarations per element.
///
/// Additional styles are applied after the document styles as a user-origin
/// layer: later declarations win regardless of selector specificity. This
/// makes them suitable for reader settings and app-provided overrides.
class CssEngine {
  final dom.DocumentFragment _root;
  final Map<String, Map<String, String>> _baseElementMap;
  late Map<String, Map<String, String>> _elementMap;
  Map<String, Map<String, String>> _additionalDeclarations = const {};
  var _revision = 0;

  CssEngine({
    required dom.DocumentFragment root,
    Map<String, Map<String, String>> additionalStyles = const {},
  }) : _root = root,
       _baseElementMap = _computeStyles(root) {
    final result = _applyAdditionalStyles(_baseElementMap, additionalStyles);
    _elementMap = result.styles;
    _additionalDeclarations = result.declarations;
  }

  int get stylesRevision => _revision;

  Map<String, String>? stylesFor(dom.Element element) {
    final nodeIndex = element.attributes[HtmlConstants.nodeIndexAttribute];
    if (nodeIndex == null) return null;

    final declarations = _additionalDeclarations[nodeIndex];
    if (declarations != null) {
      _appendInlineStyles(element, declarations);
    }

    return _elementMap[nodeIndex];
  }

  void updateAdditionalStyles(Map<String, Map<String, String>> styles) {
    final result = _applyAdditionalStyles(_baseElementMap, styles);
    _elementMap = result.styles;
    _additionalDeclarations = result.declarations;
    _revision++;
  }

  ({
    Map<String, Map<String, String>> styles,
    Map<String, Map<String, String>> declarations,
  })
  _applyAdditionalStyles(
    Map<String, Map<String, String>> base,
    Map<String, Map<String, String>> additionalStyles,
  ) {
    final result = <String, Map<String, String>>{
      for (final entry in base.entries)
        entry.key: Map<String, String>.of(entry.value),
    };
    final declarationsByNode = <String, Map<String, String>>{};

    for (final entry in additionalStyles.entries) {
      try {
        final matches = _root.querySelectorAll(entry.key);
        for (final element in matches) {
          final nodeIndex =
              element.attributes[HtmlConstants.nodeIndexAttribute];
          if (nodeIndex == null) continue;

          final properties = result.putIfAbsent(nodeIndex, () => {});
          final declarations = declarationsByNode.putIfAbsent(
            nodeIndex,
            () => {},
          );
          for (final declaration in entry.value.entries) {
            // Re-insert on every assignment so the map keeps the order of the
            // last declaration for each property.
            properties.remove(declaration.key);
            properties[declaration.key] = declaration.value;
            declarations.remove(declaration.key);
            declarations[declaration.key] = declaration.value;
          }
        }
      } catch (e) {
        log.debug(
          'skipping invalid additional selector',
          attributes: {'error': e},
        );
      }
    }

    return (styles: result, declarations: declarationsByNode);
  }

  /// Appends the additional declarations to the element's inline style.
  ///
  /// `flutter_widget_from_html` applies inline styles after custom styles, so
  /// appending here makes the additional stylesheet win without dropping the
  /// book's other inline declarations.
  static void _appendInlineStyles(
    dom.Element element,
    Map<String, String> declarations,
  ) {
    if (declarations.isEmpty) return;

    final appended = declarations.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('; ');
    if (appended.isEmpty) return;

    final existing = element.attributes['style']?.trim() ?? '';
    if (existing.contains(appended)) return;

    element.attributes['style'] = existing.isEmpty
        ? '$appended;'
        : '$existing; $appended;';
  }

  static Map<String, Map<String, String>> _computeStyles(
    dom.DocumentFragment root,
  ) {
    final rules = _parseRules(root);
    final map = <String, List<_Style>>{};

    for (final rule in rules) {
      try {
        final matches = root.querySelectorAll(rule.selector);
        for (final element in matches) {
          final nodeIndex =
              element.attributes[HtmlConstants.nodeIndexAttribute];
          if (nodeIndex == null) continue;
          map.putIfAbsent(nodeIndex, () => []).add(rule);
        }
      } catch (e) {
        log.debug(
          'skipping invalid selector',
          attributes: {'error': e, 'selector': rule.selector},
        );
      }
    }

    final elementMap = <String, Map<String, String>>{};
    map.forEach((nodeIndex, rules) {
      rules.sort((a, b) {
        final specificity = a.specificity.compareTo(b.specificity);
        return specificity != 0 ? specificity : a.order.compareTo(b.order);
      });

      final properties = <String, String>{};
      for (final rule in rules) {
        for (final declaration in rule.declarations) {
          // Re-insert on every assignment so the map keeps the order of the
          // last declaration for each property.
          properties.remove(declaration.key);
          properties[declaration.key] = declaration.value;
        }
      }
      elementMap[nodeIndex] = properties;
    });

    return elementMap;
  }

  static List<_Style> _parseRules(dom.DocumentFragment root) {
    final visitor = _StyleSheetVisitor();
    final styleTags = root.querySelectorAll('style');

    for (final tag in styleTags) {
      final sheet = css.parse(tag.innerHtml);
      sheet.visit(visitor);
      tag.remove();
    }
    return visitor.rules.toList();
  }
}

class const _Specificity(final int a, final int b, final int c)
    implements Comparable<_Specificity> {
  @override
  int compareTo(_Specificity other) {
    if (a != other.a) return a.compareTo(other.a);
    if (b != other.b) return b.compareTo(other.b);
    return c.compareTo(other.c);
  }
}

class _Style(
  final String selector,
  final List<MapEntry<String, String>> declarations,
  final int order,
) {
  final _Specificity specificity;

  this : specificity = _calculateSpecificity(selector);

  static _Specificity _calculateSpecificity(String selector) {
    final group = css.parseSelectorGroup(selector);
    var a = 0, b = 0, c = 0;

    for (var seq in group?.selectors ?? []) {
      for (var simple in seq.simpleSelectorSequences) {
        final s = simple.simpleSelector;
        if (s is IdSelector) {
          a++;
        } else if (s is ClassSelector ||
            s is AttributeSelector ||
            s is PseudoClassSelector) {
          b++;
        } else if (s is ElementSelector || s is PseudoElementSelector) {
          c++;
        }
      }
    }
    return _Specificity(a, b, c);
  }
}

class _StyleSheetVisitor extends Visitor {
  final List<_Style> _rules = [];
  var _order = 0;

  List<_Style> get rules => .unmodifiable(_rules);

  @override
  void visitRuleSet(RuleSet node) {
    final declarations = <MapEntry<String, String>>[];

    for (final decl
        in node.declarationGroup.declarations.whereType<Declaration>()) {
      final expr = decl.expression;
      if (expr == null) continue;
      final printer = CssPrinter();
      expr.visit(printer);
      declarations.add(MapEntry(decl.property, printer.toString()));
    }

    final currentSelectors =
        node.selectorGroup?.selectors
            .map((s) => s.span?.text)
            .whereType<String>()
            .toSet() ??
        {};

    final order = _order++;
    for (final selectorNode in currentSelectors) {
      _rules.add(_Style(selectorNode, declarations, order));
    }
  }
}
