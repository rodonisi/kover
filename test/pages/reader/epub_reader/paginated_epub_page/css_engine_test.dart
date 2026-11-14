import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';

void main() {
  group('CssEngine', () {
    group('document styles', () {
      test('applies styles after the HTML is re-parsed', () {
        final (engine, rendered) = _render('''
          <style>
            p { color: red; }
          </style>
          <p>text</p>
        ''');

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!),
          {'color': '#f00'},
        );
      });

      test('returns null when no selector matches', () {
        final (engine, rendered) = _render('''
          <style>
            span { color: red; }
          </style>
          <p>text</p>
        ''');

        expect(engine.stylesFor(element: rendered.querySelector('p')!), isNull);
      });

      test('more specific selector wins', () {
        final (engine, rendered) = _render('''
          <style>
            p { color: red; }
            #target { color: green; }
          </style>
          <p id="target">text</p>
        ''');

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['color'],
          '#008000',
        );
      });

      test('later rule wins on equal specificity', () {
        final (engine, rendered) = _render('''
          <style>
            p { color: red; }
            p { color: blue; }
          </style>
          <p>text</p>
        ''');

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['color'],
          '#00f',
        );
      });

      test('keeps source order across style tags', () {
        final (engine, rendered) = _render('''
          <style>
            p { color: red; }
          </style>
          <style>
            p { color: blue; }
          </style>
          <p>text</p>
        ''');

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['color'],
          '#00f',
        );
      });

      test('keeps final declaration order and values', () {
        final (engine, rendered) = _render('''
          <style>
            p { margin: 0; }
            p { margin-left: 5px; }
            p { margin: 0; }
          </style>
          <p>text</p>
        ''');

        final styles = engine.stylesFor(
          element: rendered.querySelector('p')!,
        )!;
        expect(styles.entries.map((entry) => '${entry.key}: ${entry.value}'), [
          'margin-left: 5px',
          'margin: 0',
        ]);
      });

      test('returns null for an element without a node index', () {
        final engine = CssEngine(root: _source('<p>text</p>'));

        expect(engine.stylesFor(element: dom.Element.tag('p')), isNull);
      });
    });

    group('additional styles', () {
      test('matches a detached root', () {
        final root = _source(
          '<div class="kover-content"><p>text</p></div>',
        );
        final engine = CssEngine(
          root: root,
          additionalStyles: {
            '.kover-content': {'background-color': 'red'},
          },
        );

        // flutter_widget_from_html parses HTML into detached top-level nodes.
        final wrapper = _reparse(root).children.first..remove();

        expect(
          engine.stylesFor(element: wrapper)?['background-color'],
          'red',
        );
      });

      test('overrides a conflicting document declaration', () {
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

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['color'],
          'blue',
        );
      });

      test('keeps non-conflicting document declarations', () {
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

        expect(
          engine.stylesFor(
            element: rendered.querySelector('p')!,
          )?['margin-top'],
          '4px',
        );
      });

      test('universal selector matches every element', () {
        final (engine, rendered) = _render(
          '<div><p>text</p><span>inline</span></div>',
          additionalStyles: {
            '*': {'text-indent': '0'},
          },
        );

        expect(
          [
            engine.stylesFor(
              element: rendered.querySelector('p')!,
            )?['text-indent'],
            engine.stylesFor(
              element: rendered.querySelector('span')!,
            )?['text-indent'],
          ],
          ['0', '0'],
        );
      });

      test('applies an added class after invalidation', () {
        final root = _source('<p>text</p>');
        final engine = CssEngine(
          root: root,
          additionalStyles: {
            '.resume': {'color': 'red'},
          },
        );
        String? color() => engine.stylesFor(
          element: _reparse(root).querySelector('p')!,
        )?['color'];

        expect(color(), isNull);
        root.querySelector('p')!.classes.add('resume');
        engine.invalidate();

        expect(color(), 'red');
      });

      test('drops a removed class after invalidation', () {
        final root = _source('<p class="resume">text</p>');
        final engine = CssEngine(
          root: root,
          additionalStyles: {
            '.resume': {'color': 'red'},
          },
        );
        String? color() => engine.stylesFor(
          element: _reparse(root).querySelector('p')!,
        )?['color'];

        expect(color(), 'red');
        root.querySelector('p')!.classes.remove('resume');
        engine.invalidate();

        expect(color(), isNull);
      });

      test('drops previous declarations when the overlay is updated', () {
        final (engine, rendered) = _render(
          '<p>text</p>',
          additionalStyles: {
            'p': {'color': 'red'},
          },
        );

        engine.updateAdditionalStyles({
          'p': {'text-align': 'justify'},
        });

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['color'],
          isNull,
        );
      });

      test('applies new declarations when the overlay is updated', () {
        final (engine, rendered) = _render(
          '<p>text</p>',
          additionalStyles: {
            'p': {'color': 'red'},
          },
        );

        engine.updateAdditionalStyles({
          'p': {'text-align': 'justify'},
        });

        expect(
          engine.stylesFor(
            element: rendered.querySelector('p')!,
          )?['text-align'],
          'justify',
        );
      });

      test('increments stylesRevision when the overlay is updated', () {
        final (engine, _) = _render('<p>text</p>');

        engine.updateAdditionalStyles({
          'p': {'text-align': 'justify'},
        });

        expect(engine.stylesRevision, 1);
      });

      test('invalid selectors do not prevent valid selectors', () {
        final (engine, rendered) = _render(
          '<p>text</p>',
          additionalStyles: {
            'p[': {'color': 'red'},
            'p': {'margin': '0'},
          },
        );

        expect(
          engine.stylesFor(element: rendered.querySelector('p')!)?['margin'],
          '0',
        );
      });
    });
  });
}

dom.DocumentFragment _source(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}

/// Re-parses the source HTML like flutter_widget_from_html.
dom.DocumentFragment _reparse(dom.DocumentFragment root) {
  return dom.DocumentFragment.html(root.outerHtml);
}

(CssEngine, dom.DocumentFragment) _render(
  String html, {
  Map<String, Map<String, String>> additionalStyles = const {},
}) {
  final root = _source(html);
  final engine = CssEngine(root: root, additionalStyles: additionalStyles);
  return (engine, _reparse(root));
}
