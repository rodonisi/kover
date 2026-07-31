import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/reflow_engine.dart';

void main() {
  group('BinaryReflowEngine', () {
    test('when empty nodes, addNext returns false', () {
      // <div></div>
      final engine = BinaryReflowEngine(root: Element.tag('div'));

      expect(engine.addNext(), isFalse);
    });

    test('when exhausted, addNext returns false', () {
      // <div>Hello</div>
      final root = Element.tag('div')..append(Text('Hello'));
      final engine = BinaryReflowEngine(root: root);

      expect(engine.addNext(), isTrue);
      expect(engine.addNext(), isFalse);
      expect(engine.buffer.outerHtml, equals(root.outerHtml));
    });

    test('when split child on leaf node, then returns false', () {
      // <div>
      //   <img>Hello</img>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('img')..append(Text('Hello')));
      final engine = BinaryReflowEngine(root: root);

      engine.addNext();
      // Simulate the driver reporting overflow on the single unit.
      expect(engine.overflow(), isFalse);
    });

    test('when no overflow bound, addNext halves the probe range', () {
      // <div>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')));
      final engine = BinaryReflowEngine(root: root);

      // Binary search: 2, 3, 4.
      for (final expected in [2, 3, 4]) {
        expect(engine.addNext(), isTrue);
        expect(engine.buffer.nodes.length, equals(expected));
      }

      expect(engine.addNext(), isFalse);
    });

    test('when range not collapsed, splitChild shrinks the buffer', () {
      // <div>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      //   <p>aaaa</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')))
        ..append(Element.tag('p')..append(Text('aaaa')));
      final engine = BinaryReflowEngine(root: root);

      expect(engine.addNext(), isTrue);
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
      // <div>
      //   <p>one two</p>
      //   <p>three four</p>
      // </div>
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
      // <div>
      //   <p>Hello</p>
      //   <p>there</p>
      // </div>
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

    test(
      'when committing after sentences split, no sentences are lost',
      () {
        // <div>
        //   <p>Hello. There. Sentences.</p>
        // </div>
        final root = Element.tag('div')
          ..append(Element.tag('p')..append(Text('Hello. There. Sentences.')));
        final expectedCommit = Element.tag('div')
          ..append(Element.tag('p')..append(Text('Hello.')));
        final expectedNext = Element.tag('div')
          ..append(Element.tag('p')..append(Text(' There. Sentences.')));

        final engine = BinaryReflowEngine(root: root);

        engine.addNext(); // p probed
        engine.overflow(); // descend into p
        engine.addNext(); // text probed
        engine.overflow(); // split into 'Hello.', ' There.', ' Sentences.'
        engine.addNext(); // probe 'Hello. There.'
        engine.overflow(); // shrink to 'Hello.'
        engine.addNext(); // fits: re-probe 'Hello. There.'
        engine.overflow(); // ' There.' is unsplittable
        final commit = engine.commitSplit(); // backtrack ' There.'
        engine.addNext(); // probe ' There.'
        final res = engine.addNext(); // probe ' There. Sentences.'

        expect(commit.outerHtml, equals(expectedCommit.outerHtml));
        expect(res, isTrue);
        expect(engine.buffer.outerHtml, equals(expectedNext.outerHtml));
      },
    );

    test(
      'when last sentence does not end with period, then it is not lost',
      () {
        // <div>
        //   <p>Hello. There. Sentences</p>
        // </div>
        final root = Element.tag('div')
          ..append(Element.tag('p')..append(Text('Hello. There. Sentences')));
        final expectedCommit = Element.tag('div')
          ..append(Element.tag('p')..append(Text('Hello.')));
        final expectedNext = Element.tag('div')
          ..append(Element.tag('p')..append(Text(' There. Sentences')));

        final engine = BinaryReflowEngine(root: root);

        engine.addNext(); // p probed
        engine.overflow(); // descend into p
        engine.addNext(); // text probed
        engine.overflow(); // split into 'Hello.', ' There.', ' Sentences'
        engine.addNext(); // probe 'Hello. There.'
        engine.overflow(); // shrink to 'Hello.'
        engine.addNext(); // fits: re-probe 'Hello. There.'
        engine.overflow(); // ' There.' is unsplittable
        final commit = engine.commitSplit(); // backtrack ' There.'
        engine.addNext(); // probe ' There.'
        final res = engine.addNext(); // probe ' There. Sentences'

        expect(commit.outerHtml, equals(expectedCommit.outerHtml));
        expect(res, isTrue);
        expect(engine.buffer.outerHtml, equals(expectedNext.outerHtml));
      },
    );

    test('when sentences end in quote, then they split correctly', () {
      // <div>
      //   <p>"Hello." "There."</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('"Hello." "There."')));
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text('"Hello."')));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text(' "There."')));

      final engine = BinaryReflowEngine(root: root);

      engine.addNext(); // p probed
      engine.overflow(); // descend into p
      engine.addNext(); // text probed
      engine.overflow(); // split into '"Hello."', ' "There."'
      engine.addNext(); // probe '"Hello."'
      engine.overflow(); // unsplittable on an empty page: accepted as-is
      final commit = engine.commitSplit();
      final res = engine.addNext(); // probe ' "There."'

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isTrue);
      expect(engine.buffer.outerHtml, equals(expectedNext.outerHtml));
    });

    test('when splitting words, whitespace stays on the following word', () {
      // <p>Hello there white space</p>
      final root = Element.tag('p')..append(Text('Hello there white space'));
      // The page-ending word carries no trailing whitespace ...
      final expectedCommit = Element.tag('p')..append(Text('Hello there'));
      // ... it is kept on the following word: no whitespace is lost.
      final expectedNext = Element.tag('p')..append(Text(' white space'));

      final engine = BinaryReflowEngine(root: root);

      engine.addNext(); // text probed
      engine.overflow(); // split into 'Hello', ' there', ' white', ' space'
      engine.addNext(); // probe 'Hello there'
      engine.addNext(); // probe 'Hello there white'
      engine.overflow(); // ' white' is unsplittable
      final commit = engine.commitSplit(); // backtrack ' white'
      engine.addNext(); // probe ' white'
      final res = engine.addNext(); // probe ' white space'

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isTrue);
      expect(engine.buffer.outerHtml, equals(expectedNext.outerHtml));
      expect(commit.text + engine.buffer.text, equals(root.text));
    });

    test(
      'when unsplittable unit overflows an empty page, commits it as-is',
      () {
        // <div>
        //   <img>
        //   <p>after</p>
        // </div>
        final root = Element.tag('div')
          ..append(Element.tag('img'))
          ..append(Element.tag('p')..append(Text('after')));
        final engine = BinaryReflowEngine(root: root);

        engine.addNext(); // p1: img probed
        // The img overflows and cannot split; the page is empty, so it is
        // accepted for the current page. Still false: the driver commits.
        expect(engine.overflow(), isFalse);

        // The img stays on the committed page and is consumed.
        final page = engine.commitSplit();
        expect(page.outerHtml, equals('<div><img></div>'));

        // The remaining content reflows and the engine terminates.
        expect(engine.addNext(), isTrue);
        expect(engine.buffer.text, equals('after'));
        expect(engine.addNext(), isFalse);
      },
    );
  });
}
