import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/html_constants.dart';

void main() {
  group('EpubPagePreprocessor', () {
    group('node indexing', () {
      test('when elements are nested, then indexes them in order', () {
        final html = dom.DocumentFragment.html(
          '<div><p>a<span>b</span></p><p>c</p></div>',
        );

        final root = EpubPagePreprocessor(
          html: html,
          operations: [NodeIndexingOperation()],
        ).process();

        // <div index=0> wrapper
        //   <div index=1>
        //     <p index=2>
        //       a
        //       <span index=3>b</span>
        //     </p>
        //     <p index=4>c</p>
        //   </div>
        // </div>
        expect(_nodeIndexes(root), ['0', '1', '2', '3', '4']);
      });

      test('when fragment has multiple roots, then indexes them in order', () {
        final html = dom.DocumentFragment.html('text<p>a</p><p>b</p>');

        final root = EpubPagePreprocessor(
          html: html,
          operations: [NodeIndexingOperation()],
        ).process();

        expect(_nodeIndexes(root), ['0', '1', '2']);
      });

      test('when processed again, then resets and overwrites indexes', () {
        final html = dom.DocumentFragment.html('<div><p>a</p></div>');
        final preprocessor = EpubPagePreprocessor(
          html: html,
          operations: [NodeIndexingOperation()],
        );

        final first = preprocessor.process();
        final second = preprocessor.process();

        expect(_nodeIndexes(first), ['0', '1', '2']);
        expect(_nodeIndexes(second), ['0', '1', '2']);
      });

      test('when child is inserted on enter, then it is indexed too', () {
        final html = dom.DocumentFragment.html('<div><p>a</p></div>');

        final root = EpubPagePreprocessor(
          html: html,
          operations: [_InsertChildOperation(), NodeIndexingOperation()],
        ).process();

        expect(_nodeIndexes(root), ['0', '1', '2', '3', '4']);
        expect(
          root
              .querySelector('span')!
              .attributes[HtmlConstants.nodeIndexAttribute],
          '3',
        );
      });
    });

    group('walking', () {
      test('when walking, then calls hooks in operation order', () {
        final html = dom.DocumentFragment.html(
          '<div><p>a</p><span>b</span></div>',
        );
        final events = <String>[];

        EpubPagePreprocessor(
          html: html,
          operations: [
            _RecordingOperation('first', events),
            _RecordingOperation('second', events),
          ],
        ).process();

        expect(events, [
          'first:start',
          'second:start',
          'first:enter:div',
          'second:enter:div',
          'first:enter:div',
          'second:enter:div',
          'first:enter:p',
          'second:enter:p',
          'first:text:a',
          'second:text:a',
          'second:exit:p',
          'first:exit:p',
          'first:enter:span',
          'second:enter:span',
          'first:text:b',
          'second:text:b',
          'second:exit:span',
          'first:exit:span',
          'second:exit:div',
          'first:exit:div',
          'second:exit:div',
          'first:exit:div',
          'second:finish',
          'first:finish',
        ]);
      });
    });
  });
}

List<String?> _nodeIndexes(dom.DocumentFragment root) {
  return [
    for (final element in root.querySelectorAll('*'))
      element.attributes[HtmlConstants.nodeIndexAttribute],
  ];
}

final class _InsertChildOperation extends EpubPagePreprocessorOperation {
  @override
  void enter(dom.Element element) {
    if (element.localName == 'div') {
      element.append(dom.Element.tag('span')..text = 'inserted');
    }
  }
}

final class _RecordingOperation extends EpubPagePreprocessorOperation {
  _RecordingOperation(this.label, this.events);

  final String label;
  final List<String> events;

  @override
  void start(dom.DocumentFragment root) {
    events.add('$label:start');
  }

  @override
  void enter(dom.Element element) {
    events.add('$label:enter:${element.localName}');
  }

  @override
  void exit(dom.Element element) {
    events.add('$label:exit:${element.localName}');
  }

  @override
  void text(dom.Text text) {
    events.add('$label:text:${text.data}');
  }

  @override
  void finish(dom.DocumentFragment root) {
    events.add('$label:finish');
  }
}
