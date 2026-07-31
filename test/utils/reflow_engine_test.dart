import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/reflow_engine.dart';

/// Drives an engine against a fake viewport where height is the buffer's
/// text length, mimicking the provider reflow loop. Returns the committed
/// subpages plus the final buffer.
List<Element> runReflow(ReflowEngine engine, int maxHeight) {
  final pages = <Element>[];

  var guard = 0;
  while (true) {
    if (++guard > 10000) fail('reflow did not converge');

    final fits = engine.buffer.text.length <= maxHeight;

    if (fits) {
      if (engine.addNext()) continue;
      pages.add(engine.buffer.clone(true));
      return pages;
    }

    if (engine.overflow()) continue;
    pages.add(engine.commitSplit());
  }
}

Element paragraphs(int count, String text) {
  final root = Element.tag('div');
  for (var i = 0; i < count; i++) {
    root.append(Element.tag('p')..append(Text(text)));
  }
  return root;
}

void main() {
  group('BinaryReflowEngine', () {
    test('when empty nodes, addNext returns false', () {
      final engine = BinaryReflowEngine(root: Element.tag('div'));

      expect(engine.addNext(), isFalse);
    });

    test('when exhausted, addNext returns false', () {
      final root = Element.tag('div')..append(Text('Hello'));
      final engine = BinaryReflowEngine(root: root);

      expect(engine.addNext(), isTrue);
      expect(engine.addNext(), isFalse);
      expect(engine.buffer.outerHtml, equals(root.outerHtml));
    });

    test('when split child on leaf node, then returns false', () {
      final root = Element.tag('div')
        ..append(Element.tag('img')..append(Text('Hello')));
      final engine = BinaryReflowEngine(root: root);

      engine.addNext();
      // Simulate the driver reporting overflow on the single unit.
      expect(engine.overflow(), isFalse);
    });

    test('when no overflow bound, addNext halves the probe range', () {
      final root = paragraphs(8, 'aaaa');
      final engine = BinaryReflowEngine(root: root);

      // Binary search: 4, 6, 7, 8.
      for (final expected in [4, 6, 7, 8]) {
        expect(engine.addNext(), isTrue);
        expect(engine.buffer.nodes.length, equals(expected));
      }

      expect(engine.addNext(), isFalse);
    });

    test('when range not collapsed, splitChild shrinks the buffer', () {
      final root = paragraphs(8, 'aaaa');
      final engine = BinaryReflowEngine(root: root);

      expect(engine.addNext(), isTrue);
      expect(engine.buffer.nodes.length, equals(4));

      // Overflow at 4 with 0 confirmed: shrinks to midpoint 2.
      expect(engine.overflow(), isTrue);
      expect(engine.buffer.nodes.length, equals(2));

      // Overflow at 2 with 0 confirmed: shrinks to midpoint 1.
      expect(engine.overflow(), isTrue);
      expect(engine.buffer.nodes.length, equals(1));

      // 1 fits, range collapsed (2 overflows) -> re-append known overflower.
      expect(engine.addNext(), isTrue);
      expect(engine.buffer.nodes.length, equals(2));

      // Overflow at 2: boundary collapsed, descend into the 2nd paragraph.
      expect(engine.overflow(), isTrue);
      expect(engine.buffer.nodes.length, equals(2));
      expect(engine.buffer.nodes.last.nodes, isEmpty);
    });

    test('when boundary found, descends into the overflowing unit', () {
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('one two')))
        ..append(Element.tag('p')..append(Text('three four')));
      final engine = BinaryReflowEngine(root: root);

      engine.addNext(); // p1
      engine.addNext(); // p2
      // Boundary: 1 fits, 2 overflows -> descend into p2 (empty clone).
      expect(engine.overflow(), isTrue);
      expect(engine.buffer.nodes.length, equals(2));
      expect(engine.buffer.text, equals('one two'));
    });

    test('commit returns content up to split and backtracks', () {
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello')))
        ..append(Element.tag('p')..append(Text('there')));
      // The empty p2 clone is kept, matching the linear engine's commit.
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello')))
        ..append(Element.tag('p'));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text('there')));

      final engine = BinaryReflowEngine(root: root);

      engine.addNext(); // p1
      engine.addNext(); // p2
      engine.overflow(); // boundary: descend into p2 (empty clone)
      engine.addNext(); // text 'there' appended to the clone
      engine.overflow(); // single word overflows: unsplittable
      final commit = engine.commitSplit(); // backtrack 'there'
      engine.addNext(); // 'there' re-added

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(engine.buffer.outerHtml, equals(expectedNext.outerHtml));
      engine.addNext(); // p2 level fits: pop, swap the shell into the root
      expect(engine.addNext(), isFalse);
    });

    test('driver run: pages match the linear engine', () {
      final root = paragraphs(8, 'aaaa');

      final binary = runReflow(BinaryReflowEngine(root: root), 12);
      final linear = runReflow(LinearReflowEngine(root: root), 12);

      expect(
        binary.map((e) => e.outerHtml).toList(),
        equals(linear.map((e) => e.outerHtml).toList()),
      );
      expect(binary.length, greaterThan(1));
    });

    test('driver run: word splits match the linear engine', () {
      final root = Element.tag('div')
        ..append(
          Element.tag('p')..append(Text('sit aliqua labore incididunt')),
        )
        ..append(Element.tag('p')..append(Text('est aliqua eu minim')));

      final binary = runReflow(BinaryReflowEngine(root: root), 20);
      final linear = runReflow(LinearReflowEngine(root: root), 20);

      expect(
        binary.map((e) => e.outerHtml).toList(),
        equals(linear.map((e) => e.outerHtml).toList()),
      );
      expect(binary.length, greaterThan(1));
    });

    test('driver run: sentence splits match the linear engine', () {
      final root = Element.tag('div')
        ..append(
          Element.tag('p')..append(Text('Hello. There. Sentences. More here.')),
        );

      final binary = runReflow(BinaryReflowEngine(root: root), 15);
      final linear = runReflow(LinearReflowEngine(root: root), 15);

      expect(
        binary.map((e) => e.outerHtml).toList(),
        equals(linear.map((e) => e.outerHtml).toList()),
      );
      expect(binary.length, greaterThan(1));
    });

    test('driver run: nested elements match the linear engine', () {
      final root = Element.tag('div')
        ..append(
          Element.tag('div')
            ..append(Element.tag('p')..append(Text('alpha beta gamma')))
            ..append(Element.tag('p')..append(Text('delta epsilon'))),
        )
        ..append(Element.tag('p')..append(Text('zeta eta theta')));

      final binary = runReflow(BinaryReflowEngine(root: root), 14);
      final linear = runReflow(LinearReflowEngine(root: root), 14);

      expect(
        binary.map((e) => e.outerHtml).toList(),
        equals(linear.map((e) => e.outerHtml).toList()),
      );
      expect(binary.length, greaterThan(1));
    });

    test('driver run: no content is lost', () {
      final root = Element.tag('div')
        ..append(
          Element.tag('p')..append(Text('one two. three four five. six')),
        )
        ..append(Element.tag('img'))
        ..append(Element.tag('p')..append(Text('seven eight nine')));

      final pages = runReflow(BinaryReflowEngine(root: root), 10);

      // Exact join: no whitespace is lost across page boundaries.
      expect(pages.map((e) => e.text).join(), equals(root.text));
      expect(
        pages.any((e) => e.querySelector('img') != null),
        isTrue,
      );
    });

    test('word units keep whitespace on the following word', () {
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('a b')));
      final engine = BinaryReflowEngine(root: root);

      engine.addNext(); // p
      engine.overflow(); // descend into p
      engine.addNext(); // text 'a b'
      engine.overflow(); // split into words ['a', ' b']

      engine.addNext();
      expect(engine.buffer.text, equals('a'));
      engine.addNext();
      expect(engine.buffer.text, equals('a b'));
    });

    test('driver run: whole content fits in one page', () {
      final root = paragraphs(2, 'aaaa');

      final binary = runReflow(BinaryReflowEngine(root: root), 100);
      final linear = runReflow(LinearReflowEngine(root: root), 100);

      expect(binary.length, equals(1));
      expect(
        binary.map((e) => e.outerHtml).toList(),
        equals(linear.map((e) => e.outerHtml).toList()),
      );
    });
  });
}
