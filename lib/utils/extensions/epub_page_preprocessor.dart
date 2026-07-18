import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/extensions/element.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';

extension EpubPagePreprocessor on DocumentFragment {
  DocumentFragment preprocessForRender() {
    final root = DocumentFragment();
    final wrapper = Element.tag('div')
      ..className = HtmlConstants.kavitaWrapperClass
      ..append(
        Element.tag('div')
          ..className = HtmlConstants.koverWrapperClass
          ..append(clone(true)),
      );
    root.append(wrapper);

    final rules = _extractAllRules(root);

    final elementMap = _matchRulesToElements(root, rules);
    _applyInlinedStyles(elementMap);
    _applyScrollIds(root);

    return root;
  }

  static List<_Style> _extractAllRules(DocumentFragment root) {
    final rules = <_Style>[];
    final styleTags = root.querySelectorAll('style');

    for (final tag in styleTags) {
      final sheet = css.parse(tag.innerHtml);
      final visitor = _StyleSheetVisitor();
      sheet.visit(visitor);
      rules.addAll(visitor.rules);
      tag.remove();
    }
    return rules;
  }

  static Map<Element, List<_Style>> _matchRulesToElements(
    DocumentFragment root,
    List<_Style> rules,
  ) {
    final map = <Element, List<_Style>>{};
    for (final rule in rules) {
      try {
        final matches = root.querySelectorAll(rule.selector);
        for (final el in matches) {
          map.putIfAbsent(el, () => []).add(rule);
        }
      } catch (e) {
        log.warning(
          'skipping invalid selector',
          attributes: {
            'selector': rule.selector,
            'error': e,
          },
        );
      }
    }
    return map;
  }

  static void _applyInlinedStyles(Map<Element, List<_Style>> elementMap) {
    elementMap.forEach((element, rules) {
      rules.sort((a, b) => a.specificity.compareTo(b.specificity));

      final newStyles = rules
          .expand((r) => r.properties.entries)
          .map((e) => '${e.key}: ${e.value};')
          .join(' ');

      final existing = element.attributes['style'] ?? '';
      final separator = (existing.isNotEmpty && !existing.trim().endsWith(';'))
          ? ';'
          : '';

      element.attributes['style'] = '$existing$separator $newStyles'.trim();
    });
  }

  static void _applyScrollIds(DocumentFragment root) {
    void walk(Element el) {
      el.attributes[HtmlConstants.scrollIdAttribute] = el.xpath();
      for (final child in el.children) {
        walk(child);
      }
    }

    for (final child in root.children) {
      walk(child);
    }
  }
}

class _Specificity implements Comparable<_Specificity> {
  final int a, b, c;

  const _Specificity(this.a, this.b, this.c);

  @override
  int compareTo(_Specificity other) {
    if (a != other.a) return a.compareTo(other.a);
    if (b != other.b) return b.compareTo(other.b);
    return c.compareTo(other.c);
  }
}

class _Style {
  final String selector;
  final Map<String, String> properties;
  final _Specificity specificity;

  _Style(this.selector, this.properties)
    : specificity = _calculateSpecificity(selector);

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
  final List<_Style> rules = [];

  @override
  void visitRuleSet(RuleSet node) {
    final properties = <String, String>{};

    for (final decl
        in node.declarationGroup.declarations.whereType<Declaration>()) {
      final expr = decl.expression;
      if (expr == null) return;
      final printer = CssPrinter();
      expr.visit(printer);
      final value = printer.toString();
      properties[decl.property] = value;
    }

    final currentSelectors =
        node.selectorGroup?.selectors
            .map((s) => s.span?.text)
            .whereType<String>()
            .toSet() ??
        {};

    for (final selectorNode in currentSelectors) {
      rules.add(_Style(selectorNode, Map.from(properties)));
    }
  }
}
