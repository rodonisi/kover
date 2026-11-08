import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';

void main() {
  group('CssEngine', () {
    test('when element is re-parsed, then styles are found by node index', () {
      final (engine, rendered) = _render('''
        <style>
          p { color: red; }
        </style>
        <p>text</p>
      ''');

      final styles = engine.stylesFor(rendered.querySelector('p')!);

      expect(styles, {'color': '#f00'});
    });

    test('when selector has no match, then styles are null', () {
      final (engine, rendered) = _render('''
        <style>
          span { color: red; }
        </style>
        <p>text</p>
      ''');

      expect(engine.stylesFor(rendered.querySelector('p')!), isNull);
    });

    test('when specificity differs, then more specific rule wins', () {
      final (engine, rendered) = _render('''
        <style>
          p { color: red; }
          #target { color: green; }
        </style>
        <p id="target">text</p>
      ''');

      final styles = engine.stylesFor(rendered.querySelector('p')!);

      expect(styles?['color'], '#008000');
    });

    test('when specificity ties, then later rule wins', () {
      final (engine, rendered) = _render('''
        <style>
          p { color: red; }
          p { color: blue; }
        </style>
        <p>text</p>
      ''');

      final styles = engine.stylesFor(rendered.querySelector('p')!);

      expect(styles?['color'], '#00f');
    });

    test(
      'when later shorthand resets earlier longhand, then order is kept',
      () {
        final (engine, rendered) = _render('''
        <style>
          p { margin: 0; }
          p { margin-left: 5px; }
          p { margin: 0; }
        </style>
        <p>text</p>
      ''');

        final styles = engine.stylesFor(rendered.querySelector('p')!);

        expect(styles?.keys, ['margin-left', 'margin']);
        expect(styles?['margin-left'], '5px');
        expect(styles?['margin'], '0');
      },
    );

    test('when rules split across style tags, then source order is kept', () {
      final (engine, rendered) = _render('''
        <style>
          p { color: red; }
        </style>
        <style>
          p { color: blue; }
        </style>
        <p>text</p>
      ''');

      final styles = engine.stylesFor(rendered.querySelector('p')!);

      expect(styles?['color'], '#00f');
    });

    test(
      'when additional styles match, then they win over document styles',
      () {
        final (engine, rendered) = _render(
          '''
        <style>
          p { color: red; margin-top: 4px; }
        </style>
        <p>text</p>
      ''',
          additionalStyles: {
            'p': {'color': 'blue'},
          },
        );

        final styles = engine.stylesFor(rendered.querySelector('p')!);

        expect(styles?['color'], 'blue');
        expect(styles?['margin-top'], '4px');
      },
    );

    test('when additional styles use a universal selector, then all elements match', () {
      final (engine, rendered) = _render(
        '''
        <div><p>text</p><span>inline</span></div>
      ''',
        additionalStyles: {
          '*': {'text-indent': '0'},
        },
      );

      expect(
        engine.stylesFor(rendered.querySelector('p')!)?['text-indent'],
        '0',
      );
      expect(
        engine.stylesFor(rendered.querySelector('span')!)?['text-indent'],
        '0',
      );
    });

    test(
      'when a class is added to the source, then it applies on re-parse '
      'without updating the styles',
      () {
        final root = EpubPagePreprocessor(
          html: dom.DocumentFragment.html('<p>text</p>'),
          operations: [NodeIndexingOperation()],
        ).process();
        final engine = CssEngine(
          root: root,
          additionalStyles: {
            '.resume': {'color': 'red'},
          },
        );

        var rendered = dom.DocumentFragment.html(root.outerHtml);
        expect(
          engine.stylesFor(rendered.querySelector('p')!)?['color'],
          isNull,
        );

        root.querySelector('p')!.classes.add('resume');

        rendered = dom.DocumentFragment.html(root.outerHtml);
        expect(
          engine.stylesFor(rendered.querySelector('p')!)?['color'],
          'red',
        );
      },
    );

    test(
      'when additional styles are updated, then the overlay is replaced',
      () {
        final (engine, rendered) = _render(
          '<p>text</p>',
          additionalStyles: {
            'p': {'color': 'red'},
          },
        );

        final paragraph = rendered.querySelector('p')!;
        expect(engine.stylesFor(paragraph)?['color'], 'red');

        engine.updateAdditionalStyles({
          'p': {'text-align': 'justify'},
        });

        expect(engine.stylesFor(paragraph)?['color'], isNull);
        expect(engine.stylesFor(paragraph)?['text-align'], 'justify');
      },
    );
  });
}

/// Builds an engine, then re-parses its HTML like flutter_widget_from_html.
(CssEngine, dom.DocumentFragment) _render(
  String html, {
  Map<String, Map<String, String>> additionalStyles = const {},
}) {
  final root = EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
  final engine = CssEngine(root: root, additionalStyles: additionalStyles);
  final rendered = dom.DocumentFragment.html(root.outerHtml);
  return (engine, rendered);
}
