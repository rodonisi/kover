import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/element_cursor.dart';

void main() {
  group('ElementCursor', () {
    test('when empty nodes, next returns null', () {
      // <div></div>
      final root = Element.tag('div');
      final cursor = ElementCursor(root: root);

      final res = cursor.addNext();

      expect(res, isNull);
    });

    test('when exhausted, next returns null', () {
      // <div>Hello</div>
      final root = Element.tag('div')..append(Text('Hello'));
      final cursor = ElementCursor(root: root);

      cursor.addNext();
      final res = cursor.addNext();

      expect(res, isNull);
    });

    test('when commit split, then root clone up to split is returned', () {
      // <div>
      //   <p>Hello</p>
      //   <p>there</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello')))
        ..append(Element.tag('p')..append(Text('there')));
      final expected = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.addNext();
      final res = cursor.commitSplit();

      expect(res.outerHtml, equals(expected.outerHtml));
    });

    test('after committed split, next returns the next child', () {
      // <div>
      //   <p>Hello</p>
      //   <p>there</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello')))
        ..append(Element.tag('p')..append(Text('there')));
      final expected = Element.tag('div')
        ..append(Element.tag('p')..append(Text('there')));

      final cursor = ElementCursor(root: root);

      cursor.addNext(); // p0
      cursor.addNext(); // p1
      cursor.commitSplit(); // p0
      final res = cursor.addNext(); // p1
      final next = cursor.addNext(); // exhausted

      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expected.outerHtml));
      expect(next, isNull);
    });

    test(
      'when split child on leaf node, then returns false',
      () {
        // <div>
        //   <img>Hello</img>
        // </div>
        final root = Element.tag('div')
          ..append(Element.tag('img')..append(Text('Hello')));
        final cursor = ElementCursor(root: root);

        cursor.addNext();
        final res = cursor.splitChild();

        expect(res, isFalse);
      },
    );

    test('when split child on non-leaf node, then returns true', () {
      // <div>
      //   <div>Hello</div>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('div')..append(Text('Hello')));
      final cursor = ElementCursor(root: root);

      cursor.addNext();
      final res = cursor.splitChild();

      expect(res, isTrue);
    });

    test(
      'when child split, then addNext adds from child',
      () {
        // <div>
        //   <div>Hello there</div>
        // </div>
        final root = Element.tag('div')
          ..append(
            Element.tag('div')..append(Text('Hello')..append(Text('there'))),
          );
        final expected = Element.tag('div')
          ..append(Element.tag('div')..append(Text('Hello')));

        final cursor = ElementCursor(root: root);

        cursor.addNext();
        cursor.splitChild();
        final res = cursor.addNext();

        expect(res, isNotNull);
        expect(res!.outerHtml, equals(expected.outerHtml));
      },
    );

    test(
      'when child split commit, then backtracks and continues from child',
      () {
        // <div>
        //   <div>Hello</div>
        //   <p>there</p>
        // </div>
        final root = Element.tag('div')
          ..append(Element.tag('div'))
          ..append(Element.tag('p'));
        final expectedCommit = Element.tag('div')..append(Element.tag('div'));
        final expectedNext = Element.tag('div')..append(Element.tag('p'));

        final cursor = ElementCursor(root: root);

        cursor.addNext(); // div
        cursor.splitChild(); // div
        cursor.addNext(); // inner div
        cursor.addNext(); // p
        final commit = cursor.commitSplit();
        final res = cursor.addNext();
        final cont = cursor.addNext();

        expect(commit.outerHtml, equals(expectedCommit.outerHtml));

        expect(res, isNotNull);
        expect(res!.outerHtml, equals(expectedNext.outerHtml));
        expect(cont, isNull);
      },
    );

    test('when splitting text node, addNext adds words', () {
      // <div>
      //   <p>Hello there</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello there')));
      final expected = Element.tag('div')
        ..append(Element.tag('p')..append(Text(r'Hello ')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.splitChild();
      final res = cursor.addNext();

      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expected.outerHtml));
    });

    test('when splitting text node, addNext adds words', () {
      // <div>
      //   <p>Hello there</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello there')));
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text(r'Hello ')));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text('there')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.addNext();
      final commit = cursor.commitSplit();
      final res = cursor.addNext();

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expectedNext.outerHtml));
    });

    test('when committing after sentences split, no sentences are lost', () {
      // <div>
      //  <p>Hello. There.</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello. There. Sentences.')));
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text(r'Hello. ')));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text('There. Sentences.')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.addNext();
      final commit = cursor.commitSplit();
      final res = cursor.addNext();

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expectedNext.outerHtml));
    });

    test('when last sentece does not end with period, then it is not lost', () {
      // <div>
      //  <p>Hello. There. Sentences</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('Hello. There. Sentences')));
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text(r'Hello. ')));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text('There. Sentences')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.addNext();
      final commit = cursor.commitSplit();
      final res = cursor.addNext();

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expectedNext.outerHtml));
    });

    test('when sentences end in quote, then they split correctly', () {
      // <div>
      //  <p>Hello. "There."</p>
      // </div>
      final root =
          Element.tag(
            'div',
          )..append(
            Element.tag('p')..append(Text('"Hello." "There."')),
          );
      final expectedCommit = Element.tag('div')
        ..append(Element.tag('p')..append(Text(r'"Hello." ')));
      final expectedNext = Element.tag('div')
        ..append(Element.tag('p')..append(Text('"There."')));

      final cursor = ElementCursor(root: root);

      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.splitChild();
      cursor.addNext();
      cursor.addNext();
      final commit = cursor.commitSplit();
      final res = cursor.addNext();

      expect(commit.outerHtml, equals(expectedCommit.outerHtml));
      expect(res, isNotNull);
      expect(res!.outerHtml, equals(expectedNext.outerHtml));
    });

    test('complete split run', () {
      // <div>
      //   <p>sit aliqua labore incididunt</p>
      //   <p>est aliqua eu minim</p>
      // </div>
      final root = Element.tag('div')
        ..append(Element.tag('p')..append(Text('sit aliqua labore incididunt')))
        ..append(Element.tag('p')..append(Text('est aliqua eu minim')));
      final expectedFirstSplit = Element.tag(
        'div',
      )..append(Element.tag('p')..append(Text(r'sit aliqua ')));
      final expectedSecondSplit = Element.tag('div')
        ..append(Element.tag('p')..append(Text('labore incididunt')))
        ..append(Element.tag('p')..append(Text('est aliqua eu minim')));

      final cursor = ElementCursor(root: root);

      cursor.addNext(); // div
      cursor.splitChild(); // div
      cursor.addNext(); // p0
      cursor.splitChild(); // p0
      cursor.addNext(); // text 'sit'
      cursor.addNext(); // text 'sit aliqua'
      cursor.addNext(); // text 'sit aliqua labore'
      final firstCommit = cursor.commitSplit(); // text 'sit aliqua'
      cursor.addNext(); // text 'labore incididunt'
      final second = cursor.addNext(); // p1
      final next = cursor.addNext(); // exhausted

      expect(firstCommit.outerHtml, equals(expectedFirstSplit.outerHtml));
      expect(second, isNotNull);
      expect(second!.outerHtml, equals(expectedSecondSplit.outerHtml));
      expect(next, isNull);
    });
  });
}
