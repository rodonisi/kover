import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller_status.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/probes/epub_measurements_collector.dart';
import 'package:kover/utils/html_constants.dart';

void main() {
  group('EpubPaginator', () {
    test('renders a document that fits on a single page', () {
      final paginator = _paginator('<div><p>Only page</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      paginator.paginate([
        _line(nodeIndex: block, bottom: 10),
      ], 100);

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

    test('keeps page boundaries between consecutive subpages', () {
      final paginator = _paginator(
        '<div><p>ONE TWO THREE FOUR FIVE SIX</p></div>',
      );
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
          offset: 4,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 20,
          bottom: 30,
          offset: 8,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 30,
          bottom: 40,
          offset: 14,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 40,
          bottom: 50,
          offset: 19,
          childPath: const [0],
        ),
        _line(
          nodeIndex: block,
          top: 50,
          bottom: 60,
          offset: 24,
          childPath: const [0],
        ),
      ], 20);

      expect(paginator.subpageCount, 3);

      final pages = [
        paginator.getSubpage(0),
        paginator.getSubpage(1),
        paginator.getSubpage(2),
      ];

      expect(pages[0], contains('ONE TWO'));
      expect(pages[0], isNot(contains('THREE')));

      expect(pages[1], contains('THREE FOUR'));
      expect(pages[1], isNot(contains('ONE')));
      expect(pages[1], isNot(contains('FIVE')));

      expect(pages[2], contains('FIVE SIX'));
      expect(pages[2], isNot(contains('THREE')));
    });

    test('splits at a block boundary and keeps wrappers', () {
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
    });

    test('handles a break after a line break', () {
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

  group('PaginatedEpubPageController', () {
    test('paginates against the viewport height, not the content height', () {
      final controller = PaginatedEpubPageController();
      final paginator = _paginator('<div><p>AAAA BBBB CCCC</p></div>');
      final block = _nodeIndexOf(paginator.root, 'p');

      controller.attachRoot(paginator.root);
      controller.processMeasurements(
        EpubMeasurements(
          // The whole document is much taller than the viewport.
          contentSize: const Size(100, 1000),
          units: [
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
          ],
        ),
        pageHeight: 25,
      );

      expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      expect(controller.subpageCount, 2);
      expect(controller.getSubpage(0), isNotEmpty);
      expect(controller.currentSubpage, 0);

      controller.nextSubpage();
      expect(controller.currentSubpage, 1);

      controller.nextSubpage();
      expect(controller.currentSubpage, 1);
    });
  });
}

EpubPaginator _paginator(String html) =>
    EpubPaginator(root: dom.DocumentFragment.html(html));

int _nodeIndexOf(dom.DocumentFragment root, String selector) =>
    _nodeIndex(root.querySelector(selector)!);

int _nodeIndex(dom.Element element) =>
    int.parse(element.attributes[HtmlConstants.nodeIndexAttribute]!);

EpubBreakUnit _line({
  required int nodeIndex,
  double top = 0,
  required double bottom,
  int offset = 0,
  List<int> childPath = const [],
  bool afterNode = false,
  bool isLeaf = false,
}) {
  final start = EpubBreak(
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
        )
      : EpubLineUnit(
          start: start,
          nodeIndex: nodeIndex,
          top: top,
          bottom: bottom,
        );
}
