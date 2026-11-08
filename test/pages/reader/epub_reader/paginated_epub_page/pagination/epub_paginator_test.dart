import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/pagination/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('EpubPaginator', () {
    test('renders a document that fits on a single page', () {
      final paginator = _paginator('<div><p>Only page</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([_line(nodeIndex: block, bottom: 10)], 100);

      expect(paginator.subpageCount, 1);
      expect(paginator.getSubpage(0), contains('Only page'));
    });

    test('splits a paragraph at line offsets', () {
      final paginator = _paginator('<div><p>AAAA BBBB CCCC</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([
        _line(
          nodeIndex: block,
          top: 0,
          bottom: 10,
          offset: 0,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 10,
          bottom: 20,
          offset: 5,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 20,
          bottom: 30,
          offset: 10,
          childPath: const [0],
        ),
      ], 25);

      expect(paginator.subpageCount, 2);

      final first = paginator.getSubpage(0);
      final second = paginator.getSubpage(1);

      expect(first, contains('AAAA BBBB'));
      expect(first, isNot(contains('CCCC')));

      expect(second, contains('CCCC'));
      expect(second, isNot(contains('AAAA')));
    });

    test('marks a paragraph continued from the previous page', () {
      final paginator = _paginator('<div><p>AAAA BBBB CCCC</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([
        _line(
          nodeIndex: block,
          top: 0,
          bottom: 10,
          offset: 0,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 10,
          bottom: 20,
          offset: 5,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 20,
          bottom: 30,
          offset: 10,
          childPath: const [0],
        ),
      ], 25);

      final first = dom.DocumentFragment.html(paginator.getSubpage(0));
      final second = dom.DocumentFragment.html(paginator.getSubpage(1));

      expect(
        first
            .querySelector('p')!
            .attributes
            .containsKey(HtmlConstants.splitParagraphAttribute),
        isFalse,
      );
      expect(
        second
            .querySelector('p')!
            .attributes
            .containsKey(HtmlConstants.splitParagraphAttribute),
        isTrue,
      );
    });

    test('starts a new page when a unit ends exactly at the page limit', () {
      final paginator = _paginator('<div><p>AAAA BBBB</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([
        _line(
          nodeIndex: block,
          top: 0,
          bottom: 10,
          offset: 0,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 10,
          bottom: 20,
          offset: 5,
          childPath: const [0],
        ),
      ], 20);

      expect(paginator.subpageCount, 2);
      expect(paginator.getSubpage(0), contains('AAAA'));
      expect(paginator.getSubpage(0), isNot(contains('BBBB')));
      expect(paginator.getSubpage(1), contains('BBBB'));
    });

    test('keeps wrapper elements when splitting at a block boundary', () {
      final paginator = _paginator(
        '<div class="kavita-wrapper">'
        '<div class="kover-wrapper">'
        '<p>Intro</p>'
        '<p>Second</p>'
        '</div>'
        '</div>',
      );
      final paragraphs = paginator.root.querySelectorAll('p');
      final firstBlock = _nodeIndex(paragraphs[0]);
      final secondBlock = _nodeIndex(paragraphs[1]);

      paginator.paginate([
        _line(nodeIndex: firstBlock, top: 0, bottom: 10),
        _line(nodeIndex: secondBlock, top: 20, bottom: 30),
      ], 20);

      expect(paginator.subpageCount, 2);

      final first = paginator.getSubpage(0);
      final last = paginator.getSubpage(1);

      expect(first, contains('Intro'));
      expect(first, isNot(contains('Second')));
      expect(first, contains('kover-wrapper'));

      expect(last, contains('Second'));
      expect(last, isNot(contains('Intro')));
      expect(last, contains('kover-wrapper'));
      expect(
        dom.DocumentFragment.html(
              last,
            )
            .querySelector('p')!
            .attributes
            .containsKey(HtmlConstants.splitParagraphAttribute),
        isFalse,
      );
    });

    test('splits after a line break', () {
      final paginator = _paginator('<div><p>aa<br>bb</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([
        _line(nodeIndex: block, bottom: 10, childPath: const [0]),
        _line(
          nodeIndex: block,
          top: 10,
          bottom: 20,
          childPath: const [1],
          afterNode: true,
        ),
      ], 15);

      expect(paginator.subpageCount, 2);

      final first = paginator.getSubpage(0);
      final last = paginator.getSubpage(1);

      expect(first, contains('aa'));
      expect(first, isNot(contains('bb')));

      expect(last, contains('bb'));
      expect(last, isNot(contains('aa')));
    });

    test('splits before a leaf element', () {
      final paginator = _paginator(
        '<div><p>Before</p><img src="image.png"></div>',
      );
      final image = _nodeIndexOf(paginator.root, 'img');

      paginator.paginate([
        _line(nodeIndex: _nodeIndexOf(paginator.root, 'p'), top: 0, bottom: 10),
        _line(nodeIndex: image, top: 20, bottom: 30, isLeaf: true),
      ], 15);

      expect(paginator.subpageCount, 2);

      final first = paginator.getSubpage(0);
      final last = paginator.getSubpage(1);

      expect(first, contains('Before'));
      expect(first, isNot(contains('<img')));

      expect(last, contains('<img'));
      expect(last, isNot(contains('Before')));
    });

    test('returns no subpage before pagination and for invalid indices', () {
      final paginator = _paginator('<div><p>Text</p></div>');

      expect(paginator.subpageCount, 0);
      expect(paginator.getSubpage(0), isEmpty);

      final block = _nodeIndexOf(paginator.root, 'p');
      paginator.paginate([_line(nodeIndex: block, bottom: 10)], 100);

      expect(paginator.getSubpage(-1), isEmpty);
      expect(paginator.getSubpage(1), isEmpty);
    });
  });
}

EpubPaginator _paginator(String html) {
  final root = EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
  return EpubPaginator(root: root);
}

int _nodeIndexOf(dom.DocumentFragment root, String selector) =>
    _nodeIndex(root.querySelector(selector)!);

int _nodeIndex(dom.Element element) =>
    int.parse(element.attributes[HtmlConstants.nodeIndexAttribute]!);

EpubMeasureUnit _line({
  required int nodeIndex,
  double top = 0,
  required double bottom,
  int offset = 0,
  List<int> childPath = const [],
  bool afterNode = false,
  bool isLeaf = false,
  double topInset = 0,
  double bottomInset = 0,
}) {
  final start = EpubPosition(
    blockNodeIndex: nodeIndex,
    childPath: childPath,
    offset: offset,
    afterNode: afterNode,
  );

  return isLeaf
      ? EpubLeafUnit(
          start: start,
          nodeIndex: nodeIndex,
          top: top,
          bottom: bottom,
          topInset: topInset,
          bottomInset: bottomInset,
        )
      : EpubLineUnit(
          start: start,
          nodeIndex: nodeIndex,
          top: top,
          bottom: bottom,
          topInset: topInset,
          bottomInset: bottomInset,
        );
}
