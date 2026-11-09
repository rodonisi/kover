import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_content.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_controller.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/pagination/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:material_ui/material_ui.dart';

const _settings = PaginatedEpubPageSettings(
  horizontalMarginSize: 0,
  verticalMarginSize: 0,
  fontSize: 14,
  paragraphSpacing: 0,
  lineHeight: 1.5,
  wordSpacing: 0,
  letterSpacing: 0,
  fontFamily: null,
  removeParagraphIndent: false,
  highlightResumePoint: false,
  canScroll: true,
  reduceAnimations: false,
  ignoreSafeArea: false,
  textAlignment: .left,
  mode: .horizontal,
);

void main() {
  testWidgets('generated pages with preserved block padding fit the viewport', (
    tester,
  ) async {
    const viewport = Size(180, 120);
    final text = List.filled(40, 'padding line').join(' ');
    final root = _preprocess(
      '<div style="padding: 32px 0">'
      '<p style="margin: 0">$text</p>'
      '</div>',
    );

    final paginator = await _paginate(tester, root, viewport);

    expect(paginator.subpageCount, greaterThan(1));
    await _expectPagesFit(tester, paginator, viewport);
  });

  testWidgets('production chapter pages fit the tight viewport', (
    tester,
  ) async {
    const viewport = Size(490.7, 910);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PaginatedEpubPageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: PaginatedEpubPage(
                controller: controller,
                html: dom.DocumentFragment.html(_chapterHtml()),
                settings: _settings,
              ),
            ),
          ),
        ),
      ),
    );

    for (
      var frame = 0;
      frame < 100 &&
          controller.status == PaginatedEpubPageControllerStatus.measuring;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    expect(controller.status, PaginatedEpubPageControllerStatus.ready);
    expect(controller.subpageCount, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout changes while measuring eventually reach ready', (
    tester,
  ) async {
    const viewport = Size(320, 480);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _BlockingController();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_PageHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: _PageHarness(
              key: harnessKey,
              controller: controller,
              html: dom.DocumentFragment.html(_chapterHtml()),
              initialSettings: _settings,
            ),
          ),
        ),
      ),
    );

    // The first measurement completes but stays ignored, leaving the page in
    // the measuring state.
    await tester.pump();
    expect(controller.status, PaginatedEpubPageControllerStatus.measuring);

    // Simulate a slider tick while a measurement is already in progress.
    harnessKey.currentState!.apply(
      _settingsWith(horizontalMarginSize: 8),
    );
    controller.blockMeasurements = false;
    await tester.pump();
    await tester.pump();

    expect(controller.status, PaginatedEpubPageControllerStatus.ready);
    expect(controller.subpageCount, greaterThan(0));

    // Let the trailing debounce timer fire before the test completes.
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.status, PaginatedEpubPageControllerStatus.ready);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-layout settings do not trigger a remeasure', (
    tester,
  ) async {
    const viewport = Size(320, 240);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = PaginatedEpubPageController();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_PageHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: _PageHarness(
              key: harnessKey,
              controller: controller,
              html: dom.DocumentFragment.html(_chapterHtml()),
              initialSettings: _settings,
            ),
          ),
        ),
      ),
    );

    for (
      var frame = 0;
      frame < 100 &&
          controller.status == PaginatedEpubPageControllerStatus.measuring;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.status, PaginatedEpubPageControllerStatus.ready);

    harnessKey.currentState!.apply(
      _settingsWith(highlightResumePoint: true),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.status, PaginatedEpubPageControllerStatus.ready);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty viewport leaves the measuring state', (tester) async {
    const viewport = Size(200, 200);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = PaginatedEpubPageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: PaginatedEpubPage(
              controller: controller,
              html: dom.DocumentFragment.html(_chapterHtml()),
              settings: _settingsWith(horizontalMarginSize: 128),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(controller.status, PaginatedEpubPageControllerStatus.ready);
    expect(controller.subpageCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _PageHarness extends StatefulWidget {
  final PaginatedEpubPageController controller;
  final dom.DocumentFragment html;
  final PaginatedEpubPageSettings initialSettings;

  const _PageHarness({
    super.key,
    required this.controller,
    required this.html,
    required this.initialSettings,
  });

  @override
  State<_PageHarness> createState() => _PageHarnessState();
}

class _BlockingController extends PaginatedEpubPageController {
  bool blockMeasurements = true;

  @override
  void processMeasurements(
    EpubMeasurements measurements, {
    required Size viewport,
    Object? layoutKey,
  }) {
    if (blockMeasurements) return;
    super.processMeasurements(
      measurements,
      viewport: viewport,
      layoutKey: layoutKey,
    );
  }
}

class _PageHarnessState extends State<_PageHarness> {
  late PaginatedEpubPageSettings settings = widget.initialSettings;

  void apply(PaginatedEpubPageSettings value) {
    setState(() => settings = value);
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedEpubPage(
      controller: widget.controller,
      html: widget.html,
      settings: settings,
    );
  }
}

PaginatedEpubPageSettings _settingsWith({
  double horizontalMarginSize = 0,
  bool highlightResumePoint = false,
}) {
  return PaginatedEpubPageSettings(
    horizontalMarginSize: horizontalMarginSize,
    verticalMarginSize: 0,
    fontSize: 14,
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

String _chapterHtml() {
  final paragraphs = List.generate(20, (index) {
    return '<p style="margin: 0; text-align: justify; text-indent: 1.5em">'
        'Paragraph $index with enough justified text to wrap across several '
        'lines and exercise the final line at the chapter page boundary.'
        '</p>';
  }).join();
  return '<div style="font-family: serif; font-size: 20px; line-height: 1.2; '
      'margin: 0 5pt">'
      '<div style="margin-bottom: 2em; margin-left: 6%; margin-right: 6%; '
      'min-height: 12em; text-align: center">'
      '<h1 style="font-size: 1.29167em; line-height: 1.2; '
      'padding-top: 3.0015em; margin: 0.813857em 0 0">[ 5 ]</h1>'
      '</div>$paragraphs</div>';
}

Future<EpubPaginator> _paginate(
  WidgetTester tester,
  dom.DocumentFragment root,
  Size viewport,
) async {
  EpubMeasurements? measurements;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: EpubMeasurementsCollector(
              html: root,
              settings: _settings,
              cssEngine: CssEngine(root: root),
              onViewportChanged: (_) {},
              onMeasured: (value, _) => measurements = value,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(measurements, isNotNull);
  return EpubPaginator(root: root)
    ..paginate(measurements!.units, viewport.height);
}

Future<void> _expectPagesFit(
  WidgetTester tester,
  EpubPaginator paginator,
  Size viewport,
) async {
  for (var index = 0; index < paginator.subpageCount; index++) {
    final height = await _renderedPageHeight(
      tester,
      paginator.getSubpage(index),
      viewport,
    );

    expect(
      height,
      lessThanOrEqualTo(viewport.height + 0.01),
      reason: 'Subpage $index has height $height',
    );
  }
}

Future<double> _renderedPageHeight(
  WidgetTester tester,
  String html,
  Size viewport,
) async {
  final anchorKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: viewport.width,
                child: PaginatedEpubPageContent(
                  html: html,
                  settings: _settings,
                  viewport: viewport,
                  cssEngine: CssEngine(
                    root: dom.DocumentFragment.html(html),
                  ),
                  anchorKey: anchorKey,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final anchor = anchorKey.currentContext!.findRenderObject();
  return (anchor! as RenderBox).size.height;
}

dom.DocumentFragment _preprocess(String html) {
  return EpubPagePreprocessor(
    html: dom.DocumentFragment.html(html),
    operations: [NodeIndexingOperation()],
  ).process();
}
