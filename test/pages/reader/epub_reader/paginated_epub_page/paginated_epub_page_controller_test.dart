import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measure_unit.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/utils/constants/html_constants.dart';

const _singlePage = '<div><p>First</p></div>';
const _twoPages = '<div><p id="first">First</p><p id="target">Second</p></div>';
const _longPage = '<div><p>AAAA BBBB CCCC</p></div>';

final _resumeStyles = {
  '.${HtmlConstants.resumeParagraphClass}': {'background-color': 'red'},
};

void main() {
  group('PaginatedEpubPageController', () {
    group('pagination', () {
      test('becomes ready after measurements', () {
        final controller = _ready(_controller(_singlePage));

        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      });

      test('uses viewport height rather than content height', () {
        final controller = _ready(
          _controller(_longPage),
          linesPerParagraph: 3,
          viewportHeight: 25,
          contentHeight: 1000,
        );

        expect(controller.subpageCount, 2);
      });

      test('starts at the first subpage', () {
        final controller = _ready(_controller(_twoPages));

        expect(controller.currentSubpage, 0);
      });

      test('returns the requested subpage markup', () {
        final controller = _ready(_controller(_twoPages));

        expect(controller.getSubpage(0), contains('First'));
      });

      test('reports the subpage count', () {
        final counts = <int>[];

        _ready(_controller(_twoPages, onSubpagesCountChanged: counts.add));

        expect(counts, [2]);
      });

      test('becomes ready for empty content', () {
        final controller = _ready(_controller('<div></div>'));

        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      });

      test('empty content has no subpages', () {
        final controller = _ready(_controller('<div></div>'));

        expect(controller.subpageCount, 0);
      });

      test('empty content does not report a position', () {
        final changes = <(int, String?)>[];

        _ready(
          _controller(
            '<div></div>',
            onSubpageChanged: _record(changes),
          ),
        );

        expect(changes, isEmpty);
      });
    });

    group('navigation', () {
      test('next advances to the following subpage', () {
        final controller = _ready(_controller(_twoPages));

        controller.nextSubpage();

        expect(controller.currentSubpage, 1);
      });

      test('next stops at the last subpage', () {
        final controller = _ready(_controller(_twoPages))..jumpToSubpage(1);

        controller.nextSubpage();

        expect(controller.currentSubpage, 1);
      });

      test('previous moves to the preceding subpage', () {
        final controller = _ready(_controller(_twoPages))..jumpToSubpage(1);

        controller.previousSubpage();

        expect(controller.currentSubpage, 0);
      });

      test('previous stops at the first subpage', () {
        final controller = _ready(_controller(_twoPages));

        controller.previousSubpage();

        expect(controller.currentSubpage, 0);
      });

      test('reports the new position', () {
        final changes = <(int, String?)>[];
        final controller = _ready(
          _controller(
            _twoPages,
            onSubpageChanged: _record(changes),
          ),
        );
        changes.clear();

        controller.nextSubpage();

        expect(changes, [(1, controller.scrollIdForSubpage(1))]);
      });

      test('jumping to the current subpage is a no-op', () {
        final changes = <(int, String?)>[];
        final controller = _ready(
          _controller(
            _twoPages,
            onSubpageChanged: _record(changes),
          ),
        );
        changes.clear();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.jumpToSubpage(0);

        expect(notifications, 0);
        expect(changes, isEmpty);
      });

      test('applies a pending subpage after pagination', () {
        final controller = _controller(_twoPages)..jumpToSubpage(1);

        _paginate(controller);

        expect(controller.currentSubpage, 1);
      });

      test('keeps the pending subpage until pagination completes', () {
        final controller = _controller(_twoPages)..jumpToSubpage(1);

        expect(controller.status, PaginatedEpubPageControllerStatus.measuring);

        _paginate(controller);

        expect(controller.currentSubpage, 1);
      });

      test('reports the subpage count before becoming ready', () {
        late PaginatedEpubPageController controller;
        final statuses = <PaginatedEpubPageControllerStatus>[];

        controller = _controller(
          _twoPages,
          onSubpagesCountChanged: (_) => statuses.add(controller.status),
        );

        _paginate(controller);

        expect(statuses, [PaginatedEpubPageControllerStatus.measuring]);
      });

      test('applies a subpage set while reporting the count', () {
        late PaginatedEpubPageController controller;

        controller = _controller(
          _twoPages,
          onSubpagesCountChanged: (_) {
            if (controller.status ==
                PaginatedEpubPageControllerStatus.measuring) {
              controller.jumpToSubpage(1);
            }
          },
        );

        _paginate(controller);

        expect(controller.currentSubpage, 1);
        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      });

      test('a jump is animated by default', () {
        final controller = _ready(_controller(_twoPages));

        controller.jumpToSubpage(1);

        expect(controller.animateSubpageChange, isTrue);
      });

      test('an instant jump is flagged for the view', () {
        final controller = _ready(_controller(_twoPages));

        controller.jumpToSubpage(1, animate: false);

        expect(controller.animateSubpageChange, isFalse);
      });

      test('an instant anchor jump is flagged for the view', () {
        final controller = _ready(_controller(_twoPages));

        controller.jumpToAnchor('#target', animate: false);

        expect(controller.currentSubpage, 1);
        expect(controller.animateSubpageChange, isFalse);
      });
    });

    group('viewport', () {
      test('a changed viewport enters measuring', () {
        final controller = _ready(_controller(_singlePage));

        controller.updateViewport(const Size(100, 20));

        expect(
          controller.status,
          PaginatedEpubPageControllerStatus.measuring,
        );
      });

      test('a changed viewport notifies listeners', () {
        final controller = _ready(_controller(_singlePage));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.updateViewport(const Size(100, 20));

        expect(notifications, 1);
      });

      test('an unchanged viewport does not notify listeners', () {
        final controller = _ready(_controller(_singlePage));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.updateViewport(const Size(100, 10));

        expect(notifications, 0);
      });

      test('viewport updates do not notify while measuring', () {
        final controller = _controller(_singlePage);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.updateViewport(const Size(100, 10));

        expect(notifications, 0);
      });
    });

    group('position restoration', () {
      test('restores the subpage containing the initial scroll id', () {
        final scrollId = _scrollId(_twoPages, 1);
        final controller = _ready(
          _controller(_twoPages, initialXpath: scrollId),
        );

        expect(controller.currentSubpage, 1);
      });

      test('reports the scroll id for a subpage', () {
        final scrollId = _scrollId(_twoPages, 1);
        final controller = _ready(
          _controller(_twoPages, initialXpath: scrollId),
        );

        expect(controller.scrollIdForSubpage(1), scrollId);
      });

      test('uses onSubpageRestored instead of onSubpageChanged', () {
        final scrollId = _scrollId(_twoPages, 1);
        final restored = <(int, String?)>[];
        final changes = <(int, String?)>[];

        _ready(
          _controller(
            _twoPages,
            initialXpath: scrollId,
            onSubpageRestored: _record(restored),
            onSubpageChanged: _record(changes),
          ),
        );

        expect(restored, [(1, scrollId)]);
        expect(changes, isEmpty);
      });

      test('falls back to onSubpageChanged for restoration', () {
        final scrollId = _scrollId(_twoPages, 1);
        final changes = <(int, String?)>[];

        _ready(
          _controller(
            _twoPages,
            initialXpath: scrollId,
            onSubpageChanged: _record(changes),
          ),
        );

        expect(changes, [(1, scrollId)]);
      });

      test('reports user navigation separately after restoration', () {
        final scrollId = _scrollId(_twoPages, 1);
        final changes = <(int, String?)>[];
        final controller = _ready(
          _controller(
            _twoPages,
            initialXpath: scrollId,
            onSubpageRestored: (_, _) {},
            onSubpageChanged: _record(changes),
          ),
        );

        controller.jumpToSubpage(0);

        expect(changes, [(0, controller.scrollIdForSubpage(0))]);
      });
    });

    group('resume highlighting', () {
      test('enabling highlighting updates the subpage markup', () {
        final controller = _controllerForHighlighting();

        controller.updateSettings(_pageSettings(highlightResumePoint: true));

        expect(_resumeElement(controller, 0), isNotNull);
      });

      test('enabling highlighting applies additional styles', () {
        final controller = _controllerForHighlighting();

        controller.updateSettings(_pageSettings(highlightResumePoint: true));

        expect(_resumeColor(controller), 'red');
      });

      test('disabling highlighting removes it from the subpage markup', () {
        final controller = _controllerForHighlighting(highlight: true);

        controller.updateSettings(_pageSettings());

        expect(_resumeElement(controller, 0), isNull);
      });

      test('disabling highlighting drops additional styles', () {
        final controller = _controllerForHighlighting(highlight: true);

        controller.updateSettings(_pageSettings());

        expect(_resumeColor(controller), isNull);
      });
    });

    group('remeasurement', () {
      test('changed layout settings enter measuring', () {
        final controller = _ready(_controller(_singlePage));

        controller.updateSettings(_pageSettings(fontSize: 16));
        controller.remeasure();

        expect(
          controller.status,
          PaginatedEpubPageControllerStatus.measuring,
        );
      });

      test('changed layout settings notify on remeasurement', () {
        final controller = _ready(_controller(_singlePage));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.updateSettings(_pageSettings(fontSize: 16));
        controller.remeasure();

        expect(notifications, 1);
      });

      test('ignores measurements for a stale layout', () {
        final original = _pageSettings();
        final resized = _pageSettings(fontSize: 16);
        final controller = _ready(_controller(_singlePage, settings: original));
        controller.updateSettings(resized);
        controller.remeasure();

        _paginate(controller, layoutKey: original.layoutKey);

        expect(
          controller.status,
          PaginatedEpubPageControllerStatus.measuring,
        );
      });

      test('accepts measurements for the current layout', () {
        final resized = _pageSettings(fontSize: 16);
        final controller = _ready(_controller(_singlePage));
        controller.updateSettings(resized);
        controller.remeasure();

        _paginate(controller, layoutKey: resized.layoutKey);

        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
      });

      test('does not remeasure an unchanged layout', () {
        final controller = _ready(_controller(_singlePage));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.remeasure();

        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
        expect(notifications, 0);
      });

      test('does not remeasure for non-layout settings', () {
        final controller = _ready(_controller(_singlePage));
        controller.updateSettings(_pageSettings(highlightResumePoint: true));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.remeasure();

        expect(controller.status, PaginatedEpubPageControllerStatus.ready);
        expect(notifications, 0);
      });
    });

    group('anchors', () {
      test('finds the subpage for an anchor id', () {
        final controller = _ready(_controller(_twoPages));

        expect(controller.subpageForAnchor('target'), 1);
      });

      test('accepts a hash-prefixed anchor id', () {
        final controller = _ready(_controller(_twoPages));

        expect(controller.subpageForAnchor('#target'), 1);
      });

      test('returns null for a missing anchor', () {
        final controller = _ready(_controller(_twoPages));

        expect(controller.subpageForAnchor('missing'), isNull);
      });

      test('a pending anchor takes precedence over a pending subpage', () {
        final controller = _controller(_twoPages)
          ..jumpToSubpage(0)
          ..jumpToAnchor('target');

        _paginate(controller);

        expect(controller.currentSubpage, 1);
      });

      test('a pending anchor reports its position after pagination', () {
        final changes = <(int, String?)>[];
        final controller = _controller(
          _twoPages,
          onSubpageChanged: _record(changes),
        )..jumpToAnchor('target');

        _paginate(controller);

        expect(changes, [(1, controller.scrollIdForSubpage(1))]);
      });

      test('jumps to an anchor immediately when ready', () {
        final controller = _ready(_controller(_twoPages));

        controller.jumpToAnchor('#target');

        expect(controller.currentSubpage, 1);
      });

      test('an immediate anchor jump reports its position', () {
        final changes = <(int, String?)>[];
        final controller = _ready(
          _controller(
            _twoPages,
            onSubpageChanged: _record(changes),
          ),
        );
        changes.clear();

        controller.jumpToAnchor('#target');

        expect(changes, [(1, controller.scrollIdForSubpage(1))]);
      });
    });

    group('updateStyles', () {
      test('applies new declarations', () {
        final controller = _ready(_controller(_singlePage));

        controller.updateStyles({
          'p': {'color': 'red'},
        });

        expect(
          controller.cssEngine.stylesFor(
            element: controller.root!.querySelector('p')!,
          )?['color'],
          'red',
        );
      });

      test('notifies listeners', () {
        final controller = _ready(_controller(_singlePage));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.updateStyles({
          'p': {'color': 'red'},
        });

        expect(notifications, 1);
      });
    });
  });
}

void Function(int, String?) _record(List<(int, String?)> changes) {
  return (subpage, scrollId) => changes.add((subpage, scrollId));
}

PaginatedEpubPageController _controller(
  String html, {
  PaginatedEpubPageSettings? settings,
  String? initialXpath,
  Map<String, Map<String, String>> additionalStyles = const {},
  void Function(int subpage, String? scrollId)? onSubpageChanged,
  void Function(int subpage, String? scrollId)? onSubpageRestored,
  void Function(int count)? onSubpagesCountChanged,
}) {
  return PaginatedEpubPageController(
    onSubpageChanged: onSubpageChanged,
    onSubpageRestored: onSubpageRestored,
    onSubpagesCountChanged: onSubpagesCountChanged,
  )..attachRoot(
    dom.DocumentFragment.html(html),
    settings: settings ?? _pageSettings(),
    initialXpath: initialXpath,
    additionalStyles: additionalStyles,
  );
}

PaginatedEpubPageController _ready(
  PaginatedEpubPageController controller, {
  int linesPerParagraph = 1,
  double viewportHeight = 10,
  double? contentHeight,
}) {
  _paginate(
    controller,
    linesPerParagraph: linesPerParagraph,
    viewportHeight: viewportHeight,
    contentHeight: contentHeight,
  );
  return controller;
}

void _paginate(
  PaginatedEpubPageController controller, {
  int linesPerParagraph = 1,
  double viewportHeight = 10,
  double? contentHeight,
  Object? layoutKey,
}) {
  final units = <EpubMeasureUnit>[];
  var lineIndex = 0;

  for (final block in controller.root!.querySelectorAll('p')) {
    for (var line = 0; line < linesPerParagraph; line++) {
      units.add(
        _line(
          nodeIndex: _nodeIndex(block),
          top: lineIndex * 10,
          bottom: (lineIndex + 1) * 10,
          offset: line * 5,
          childPath: const [0],
        ),
      );
      lineIndex++;
    }
  }

  controller.processMeasurements(
    EpubMeasurements(
      contentSize: Size(100, contentHeight ?? lineIndex * 10),
      units: units,
    ),
    viewport: Size(100, viewportHeight),
    layoutKey: layoutKey,
  );
}

String _scrollId(String html, int paragraphIndex) {
  final controller = _controller(html);
  return controller.root!
      .querySelectorAll('p')[paragraphIndex]
      .attributes[HtmlConstants.scrollIdAttribute]!;
}

PaginatedEpubPageController _controllerForHighlighting({
  bool highlight = false,
}) {
  final scrollId = _scrollId(_singlePage, 0);
  return _ready(
    _controller(
      _singlePage,
      settings: _pageSettings(highlightResumePoint: highlight),
      initialXpath: scrollId,
      additionalStyles: _resumeStyles,
    ),
  );
}

dom.DocumentFragment _subpage(
  PaginatedEpubPageController controller,
  int index,
) {
  return dom.DocumentFragment.html(controller.getSubpage(index));
}

dom.Element? _resumeElement(
  PaginatedEpubPageController controller,
  int index,
) {
  return _subpage(
    controller,
    index,
  ).querySelector('.${HtmlConstants.resumeParagraphClass}');
}

String? _resumeColor(PaginatedEpubPageController controller) {
  final rendered = _subpage(controller, 0);
  return controller.cssEngine.stylesFor(
    element: rendered.querySelector('p')!,
  )?['background-color'];
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
