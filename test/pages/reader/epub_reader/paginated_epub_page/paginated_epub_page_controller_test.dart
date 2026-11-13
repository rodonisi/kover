import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('PaginatedEpubPageController', () {
    test('paginates against the viewport height, not the content height', () {
      final controller = PaginatedEpubPageController();
      controller.attachRoot(
        dom.DocumentFragment.html('<div><p>AAAA BBBB CCCC</p></div>'),
        settings: _pageSettings(),
      );
      final block = _nodeIndex(controller.root!.querySelector('p')!);

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
        viewport: const Size(100, 25),
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

    test('does not re-notify when jumping to the current subpage', () {
      final changes = <int>[];
      final controller = PaginatedEpubPageController(
        onSubpageChanged: (subpage, _) => changes.add(subpage),
      );
      controller.attachRoot(
        dom.DocumentFragment.html('<div><p>AAAA BBBB CCCC</p></div>'),
        settings: _pageSettings(),
      );
      final block = _nodeIndex(controller.root!.querySelector('p')!);

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 1000),
          units: [
            _line(nodeIndex: block, bottom: 10, childPath: const [0]),
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
        viewport: const Size(100, 25),
      );
      changes.clear();

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.jumpToSubpage(0);

      expect(notifications, 0);
      expect(changes, isEmpty);

      controller.nextSubpage();

      expect(controller.currentSubpage, 1);
      expect(notifications, 1);
      expect(changes, [1]);

      controller.jumpToSubpage(1);

      expect(notifications, 1);
      expect(changes, [1]);
    });

    test('viewportChanged only notifies when leaving the ready state', () {
      final controller = PaginatedEpubPageController();
      controller.attachRoot(
        dom.DocumentFragment.html('<div><p>Only page</p></div>'),
        settings: _pageSettings(),
      );

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateViewport(const Size(100, 10));

      expect(notifications, 0);
      expect(controller.status, PaginatedEpubPageControllerStatus.measuring);

      final block = _nodeIndex(controller.root!.querySelector('p')!);
      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 10),
          units: [_line(nodeIndex: block, bottom: 10)],
        ),
        viewport: const Size(100, 100),
      );

      expect(notifications, 1);
      expect(controller.status, PaginatedEpubPageControllerStatus.ready);

      controller.updateViewport(const Size(100, 120));

      expect(notifications, 2);
      expect(controller.status, PaginatedEpubPageControllerStatus.measuring);

      controller.updateViewport(const Size(100, 120));

      expect(notifications, 2);
    });

    test('applies a pending subpage after pagination', () {
      final controller = PaginatedEpubPageController();
      controller.attachRoot(
        dom.DocumentFragment.html('<div><p>First</p><p>Second</p></div>'),
        settings: _pageSettings(),
      );
      final blocks = [
        for (final paragraph in controller.root!.querySelectorAll('p'))
          _nodeIndex(paragraph),
      ];

      controller.setPendingSubpage(1);
      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 20),
          units: [
            _line(nodeIndex: blocks[0], bottom: 10),
            _line(nodeIndex: blocks[1], top: 10, bottom: 20),
          ],
        ),
        viewport: const Size(100, 10),
      );

      expect(controller.currentSubpage, 1);
    });

    test('resumes at the initial scroll id and reports it', () {
      final html = dom.DocumentFragment.html(
        '<div><p>first</p><p>second</p><p>third</p></div>',
      );
      final probe = PaginatedEpubPageController()
        ..attachRoot(html, settings: _pageSettings());
      final secondScrollId = probe.root!
          .querySelectorAll('p')[1]
          .attributes[HtmlConstants.scrollIdAttribute]!;

      final changes = <(int, String?)>[];
      final controller = PaginatedEpubPageController(
        onSubpageChanged: (subpage, scrollId) {
          changes.add((subpage, scrollId));
        },
      );

      controller.attachRoot(
        html,
        settings: _pageSettings(highlightResumePoint: true),
        initialXpath: secondScrollId,
        additionalStyles: {
          '.${HtmlConstants.resumeClass}': {'background-color': 'red'},
        },
      );

      final blocks = [
        for (final paragraph in controller.root!.querySelectorAll('p'))
          _nodeIndex(paragraph),
      ];

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 30),
          units: [
            _line(nodeIndex: blocks[0], bottom: 10),
            _line(nodeIndex: blocks[1], top: 10, bottom: 20),
            _line(nodeIndex: blocks[2], top: 20, bottom: 30),
          ],
        ),
        viewport: const Size(100, 10),
      );

      expect(controller.currentSubpage, 1);
      expect(changes, [(1, secondScrollId)]);
      expect(controller.scrollIdForSubpage(1), secondScrollId);
      expect(
        controller.root!.querySelector('.${HtmlConstants.resumeClass}'),
        isNotNull,
      );
      expect(
        controller.cssEngine.stylesFor(
          element: controller.root!.querySelectorAll('p')[1],
        )?['background-color'],
        'red',
      );
    });

    test(
      'updateSettings toggles the resume highlight and refreshes subpages',
      () {
        final html = dom.DocumentFragment.html('<div><p>first</p></div>');
        final probe = PaginatedEpubPageController()
          ..attachRoot(html, settings: _pageSettings());
        final scrollId = probe.root!
            .querySelector('p')!
            .attributes[HtmlConstants.scrollIdAttribute]!;

        final controller = PaginatedEpubPageController()
          ..attachRoot(
            html,
            settings: _pageSettings(),
            initialXpath: scrollId,
            additionalStyles: {
              '.${HtmlConstants.resumeClass}': {'background-color': 'red'},
            },
          );

        final block = _nodeIndex(controller.root!.querySelector('p')!);
        controller.processMeasurements(
          EpubMeasurements(
            contentSize: const Size(100, 10),
            units: [_line(nodeIndex: block, bottom: 10)],
          ),
          viewport: const Size(100, 10),
        );

        dom.DocumentFragment render() => dom.DocumentFragment.html(
          controller.getSubpage(0),
        );

        var rendered = render();
        expect(
          controller.root!.querySelector('.${HtmlConstants.resumeClass}'),
          isNull,
        );
        expect(
          rendered.querySelector('.${HtmlConstants.resumeClass}'),
          isNull,
        );

        controller.updateSettings(
          _pageSettings(highlightResumePoint: true),
        );

        expect(
          controller.root!.querySelector('.${HtmlConstants.resumeClass}'),
          isNotNull,
        );
        rendered = render();
        expect(
          rendered.querySelector('.${HtmlConstants.resumeClass}'),
          isNotNull,
        );
        expect(
          controller.cssEngine.stylesFor(
            element: rendered.querySelector('p')!,
          )?['background-color'],
          'red',
        );

        controller.updateSettings(_pageSettings());

        expect(
          controller.root!.querySelector('.${HtmlConstants.resumeClass}'),
          isNull,
        );
        rendered = render();
        expect(
          rendered.querySelector('.${HtmlConstants.resumeClass}'),
          isNull,
        );
        expect(
          controller.cssEngine.stylesFor(
            element: rendered.querySelector('p')!,
          )?['background-color'],
          isNull,
        );
      },
    );

    test('remeasure re-enters measuring for a changed layout', () {
      final controller = PaginatedEpubPageController();
      final html = dom.DocumentFragment.html('<div><p>only</p></div>');
      controller.attachRoot(html, settings: _pageSettings());
      final block = _nodeIndex(controller.root!.querySelector('p')!);

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 10),
          units: [_line(nodeIndex: block, bottom: 10)],
        ),
        viewport: const Size(100, 10),
      );
      expect(controller.status, PaginatedEpubPageControllerStatus.ready);

      var notifications = 0;
      controller.addListener(() => notifications++);

      final resized = _pageSettings(fontSize: 16);
      controller.updateSettings(resized);
      controller.remeasure();

      expect(controller.status, PaginatedEpubPageControllerStatus.measuring);
      expect(notifications, 1);

      // A measurement for the previous layout must not leave the measuring
      // state.
      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 10),
          units: [_line(nodeIndex: block, bottom: 10)],
        ),
        viewport: const Size(100, 10),
        layoutKey: _pageSettings().layoutKey,
      );

      expect(controller.status, PaginatedEpubPageControllerStatus.measuring);

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 10),
          units: [_line(nodeIndex: block, bottom: 10)],
        ),
        viewport: const Size(100, 10),
        layoutKey: resized.layoutKey,
      );
      expect(controller.status, PaginatedEpubPageControllerStatus.ready);

      notifications = 0;
      controller.remeasure();

      expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      expect(notifications, 0);
    });

    test('does not report a subpage when nothing was paginated', () {
      final changes = <(int, String?)>[];
      final controller =
          PaginatedEpubPageController(
            onSubpageChanged: (subpage, scrollId) {
              changes.add((subpage, scrollId));
            },
          )..attachRoot(
            dom.DocumentFragment.html('<div><p>only</p></div>'),
            settings: _pageSettings(),
          );

      controller.processMeasurements(
        const EpubMeasurements(
          contentSize: Size.zero,
          units: [],
        ),
        viewport: Size.zero,
      );

      expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      expect(controller.subpageCount, 0);
      expect(changes, isEmpty);
    });

    test('remeasure ignores settings changes outside the layout key', () {
      final controller = PaginatedEpubPageController();
      final html = dom.DocumentFragment.html('<div><p>only</p></div>');
      controller.attachRoot(html, settings: _pageSettings());
      final block = _nodeIndex(controller.root!.querySelector('p')!);

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 10),
          units: [_line(nodeIndex: block, bottom: 10)],
        ),
        viewport: const Size(100, 10),
      );
      expect(controller.status, PaginatedEpubPageControllerStatus.ready);

      controller.updateSettings(_pageSettings(highlightResumePoint: true));

      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.remeasure();

      expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      expect(notifications, 0);
    });

    test('maps an anchor id to the subpage that contains it', () {
      final controller = PaginatedEpubPageController();
      controller.attachRoot(
        dom.DocumentFragment.html(
          '<div><p id="first">First</p><p id="target">Second</p></div>',
        ),
        settings: _pageSettings(),
      );
      final blocks = [
        for (final paragraph in controller.root!.querySelectorAll('p'))
          _nodeIndex(paragraph),
      ];

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 20),
          units: [
            _line(nodeIndex: blocks[0], bottom: 10),
            _line(nodeIndex: blocks[1], top: 10, bottom: 20),
          ],
        ),
        viewport: const Size(100, 10),
      );

      expect(controller.subpageForAnchor('target'), 1);
      expect(controller.subpageForAnchor('#target'), 1);
      expect(controller.subpageForAnchor('missing'), isNull);
    });

    test('applies a pending anchor after pagination', () {
      final changes = <(int, String?)>[];
      final controller =
          PaginatedEpubPageController(
            onSubpageChanged: (subpage, scrollId) {
              changes.add((subpage, scrollId));
            },
          )..attachRoot(
            dom.DocumentFragment.html(
              '<div><p id="first">First</p><p id="target">Second</p></div>',
            ),
            settings: _pageSettings(),
          );
      final blocks = [
        for (final paragraph in controller.root!.querySelectorAll('p'))
          _nodeIndex(paragraph),
      ];

      controller.setPendingSubpage(0);
      controller.jumpToAnchor('target');
      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 20),
          units: [
            _line(nodeIndex: blocks[0], bottom: 10),
            _line(nodeIndex: blocks[1], top: 10, bottom: 20),
          ],
        ),
        viewport: const Size(100, 10),
      );

      expect(controller.currentSubpage, 1);
      expect(changes, [(1, controller.scrollIdForSubpage(1))]);
    });

    test('jumps to an anchor immediately when ready', () {
      final changes = <(int, String?)>[];
      final controller =
          PaginatedEpubPageController(
            onSubpageChanged: (subpage, scrollId) {
              changes.add((subpage, scrollId));
            },
          )..attachRoot(
            dom.DocumentFragment.html(
              '<div><p id="first">First</p><p id="target">Second</p></div>',
            ),
            settings: _pageSettings(),
          );
      final blocks = [
        for (final paragraph in controller.root!.querySelectorAll('p'))
          _nodeIndex(paragraph),
      ];

      controller.processMeasurements(
        EpubMeasurements(
          contentSize: const Size(100, 20),
          units: [
            _line(nodeIndex: blocks[0], bottom: 10),
            _line(nodeIndex: blocks[1], top: 10, bottom: 20),
          ],
        ),
        viewport: const Size(100, 10),
      );
      changes.clear();

      controller.jumpToAnchor('#target');

      expect(controller.currentSubpage, 1);
      expect(changes, [(1, controller.scrollIdForSubpage(1))]);
    });
  });
}

PaginatedEpubPageSettings _pageSettings({
  bool highlightResumePoint = false,
  double fontSize = 14,
  double horizontalMarginSize = 0,
}) {
  return PaginatedEpubPageSettings(
    horizontalMarginSize: horizontalMarginSize,
    verticalMarginSize: 0,
    fontSize: fontSize,
    paragraphSpacing: 0,
    lineHeight: 1.5,
    wordSpacing: 0,
    letterSpacing: 0,
    fontFamily: null,
    removeParagraphIndent: false,
    highlightResumePoint: highlightResumePoint,
    canScroll: true,
    reduceAnimations: false,
    ignoreSafeArea: false,
    textAlignment: .left,
    mode: .horizontal,
  );
}

int _nodeIndex(dom.Element element) =>
    int.parse(element.attributes[HtmlConstants.nodeIndexAttribute]!);

EpubMeasureUnit _line({
  required int nodeIndex,
  double top = 0,
  required double bottom,
  int offset = 0,
  List<int> childPath = const [],
}) {
  return EpubLineUnit(
    start: EpubPosition(
      blockNodeIndex: nodeIndex,
      childPath: childPath,
      offset: offset,
    ),
    nodeIndex: nodeIndex,
    top: top,
    bottom: bottom,
  );
}
