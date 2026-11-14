import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('EpubPagePreprocessor', () {
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

    test(
      'when processed, then wraps cloned content in the content wrapper',
      () {
        final html = dom.DocumentFragment.html('<p>a</p>');

        final root = EpubPagePreprocessor(html: html, operations: []).process();

        final wrapper = root.children.single;
        expect(wrapper.localName, 'div');
        expect(
          wrapper.classes,
          containsAll([
            HtmlConstants.kavitaWrapperClass,
            HtmlConstants.koverWrapperClass,
          ]),
        );
        expect(wrapper.children.single.localName, 'p');
        expect(wrapper.text, 'a');
      },
    );

    test(
      'when processed repeatedly, then clones without mutating the input',
      () {
        final html = dom.DocumentFragment.html('<p>a</p>');
        final preprocessor = EpubPagePreprocessor(
          html: html,
          operations: [NodeIndexingOperation()],
        );

        final first = preprocessor.process();
        final second = preprocessor.process();

        expect(
          html
              .querySelector('p')!
              .attributes
              .containsKey(HtmlConstants.nodeIndexAttribute),
          isFalse,
        );
        expect(
          first
              .querySelector('p')!
              .attributes[HtmlConstants.nodeIndexAttribute],
          '1',
        );
        expect(
          second
              .querySelector('p')!
              .attributes[HtmlConstants.nodeIndexAttribute],
          '1',
        );
        expect(identical(first, second), isFalse);
      },
    );

    test('when fragment has multiple roots, then preserves their order', () {
      final html = dom.DocumentFragment.html(
        'before<p>a</p>between<span>b</span>after',
      );

      final root = EpubPagePreprocessor(html: html, operations: []).process();

      expect(
        root.children.single.nodes.map(_describeNode),
        [
          'text:before',
          'element:p',
          'text:between',
          'element:span',
          'text:after',
        ],
      );
    });
  });
}

String _describeNode(dom.Node node) {
  return switch (node) {
    dom.Text(:final data) => 'text:$data',
    dom.Element(:final localName) => 'element:$localName',
    _ => 'other',
  };
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
