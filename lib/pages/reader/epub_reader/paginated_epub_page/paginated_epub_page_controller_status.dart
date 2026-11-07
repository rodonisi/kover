import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/resume_highlight_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:material_ui/material_ui.dart';

enum PaginatedEpubPageControllerStatus { measuring, ready }

/// Controls the state of a [PaginatedEpubPage].
class PaginatedEpubPageController({
  final void Function(int subpage, String? scrollId)? onSubpageChanged,
  final void Function(int)? onSubpagesCountChanged,
}) extends ChangeNotifier {
  EpubPaginator? _paginator;
  CssEngine? _cssEngine;
  PaginatedEpubPageControllerStatus _status = .measuring;
  int _currentSubpage = 0;
  Size? _contentViewport;
  String? _initialXpath;
  dom.Element? _highlightedElement;
  bool _resumePending = false;
  int? _pendingSubpage;
  PaginatedEpubPageSettings? _settings;
  Map<String, Map<String, String>> _additionalStyles = const {};

  PaginatedEpubPageControllerStatus get status => _status;
  dom.DocumentFragment? get root => _paginator?.root;
  Size? get contentViewport => _contentViewport;
  String? get initialXpath => _initialXpath;

  int get currentSubpage => _currentSubpage;
  int get subpageCount => _paginator?.subpageCount ?? 0;
  CssEngine get cssEngine =>
      _cssEngine ?? (throw Exception('CSS engine is not initialized'));

  void nextSubpage() {
    jumpToSubpage(_currentSubpage + 1);
  }

  void previousSubpage() {
    jumpToSubpage(_currentSubpage - 1);
  }

  void jumpToSubpage(int index) {
    final paginator = _paginator;
    if (paginator == null || index < 0 || index >= paginator.subpageCount) {
      return;
    }

    if (index == _currentSubpage) return;

    _currentSubpage = index;
    onSubpageChanged?.call(
      _currentSubpage,
      scrollIdForSubpage(_currentSubpage),
    );
    notifyListeners();
  }

  void attachRoot(
    dom.DocumentFragment html, {
    required PaginatedEpubPageSettings settings,
    String? initialXpath,
    Map<String, Map<String, String>> additionalStyles = const {},
  }) {
    final root = EpubPagePreprocessor(
      html: html,
      operations: [
        NodeIndexingOperation(),
        ScrollIdOperation(),
        ResumeHighlightOperation(
          scrollId: settings.highlightResumePoint ? initialXpath : null,
        ),
      ],
    ).process();

    _paginator = EpubPaginator(root: root);
    _cssEngine = CssEngine(
      root: root,
      additionalStyles: additionalStyles,
    );
    _additionalStyles = additionalStyles;
    _settings = settings;
    _initialXpath = initialXpath;
    _highlightedElement = settings.highlightResumePoint
        ? _findByScrollId(root, initialXpath)
        : null;
    _resumePending = initialXpath != null;
    _currentSubpage = 0;
    _contentViewport = null;
    _status = .measuring;
    notifyListeners();
  }

  void updateStyles(Map<String, Map<String, String>> additionalStyles) {
    _additionalStyles = additionalStyles;
    _cssEngine?.updateAdditionalStyles(additionalStyles);
    notifyListeners();
  }

  void updateSettings(PaginatedEpubPageSettings settings) {
    final wasHighlighting = _settings?.highlightResumePoint ?? false;
    _settings = settings;

    if (wasHighlighting == settings.highlightResumePoint) return;

    if (settings.highlightResumePoint) {
      final root = _paginator?.root;
      _highlightedElement ??= root == null
          ? null
          : _findByScrollId(root, _initialXpath);
      _highlightedElement?.classes.add(HtmlConstants.resumeClass);
    } else {
      _highlightedElement?.classes.remove(HtmlConstants.resumeClass);
    }

    _cssEngine?.updateAdditionalStyles(_additionalStyles);
    notifyListeners();
  }

  /// Sets the subpage to use as soon as pagination completes.
  ///
  /// Used while a page is still measuring and the caller already knows which
  /// subpage should become visible (for example when navigating back to the
  /// last subpage of the previous page).
  void setPendingSubpage(int? subpage) {
    _pendingSubpage = subpage;
  }

  void remeasure() {
    if (_status == .measuring) return;

    _status = .measuring;
    notifyListeners();
  }

  void processMeasurements(
    EpubMeasurements measurements, {
    required Size viewport,
  }) {
    final paginator = _paginator;
    if (paginator == null) return;

    paginator.paginate(measurements.units, viewport.height);
    _contentViewport = viewport;
    _status = .ready;

    final count = paginator.subpageCount;
    onSubpagesCountChanged?.call(count);

    final pendingSubpage = _pendingSubpage;
    _pendingSubpage = null;
    final target = _resumePending
        ? _resumeSubpage() ?? 0
        : pendingSubpage ?? _currentSubpage;
    _resumePending = false;
    _currentSubpage = count == 0 ? 0 : target.clamp(0, count - 1);

    onSubpageChanged?.call(
      _currentSubpage,
      scrollIdForSubpage(_currentSubpage),
    );
    notifyListeners();
  }

  void viewportChanged(Size viewport) {
    if (_contentViewport == viewport) return;

    _contentViewport = viewport;
    if (_status == .measuring) return;

    _status = .measuring;
    notifyListeners();
  }

  String getSubpage(int index) {
    if (_paginator == null) throw Exception('Paginator is not initialized');
    return _paginator!.getSubpage(index);
  }

  String? scrollIdForSubpage(int index) {
    return _paginator?.scrollIdForSubpage(index);
  }

  int? _resumeSubpage() {
    final paginator = _paginator;
    final xpath = _initialXpath;
    if (paginator == null || xpath == null) return null;

    final element = _findByScrollId(paginator.root, xpath);
    if (element != null) {
      dom.Element? current = element;
      while (current != null) {
        final index = int.tryParse(
          current.attributes[HtmlConstants.nodeIndexAttribute] ?? '',
        );
        if (index != null) {
          final subpage = paginator.subpageForNodeIndex(index);
          if (subpage != null) return subpage;
        }

        final parent = current.parent;
        current = parent is dom.Element ? parent : null;
      }
    }

    return paginator.subpageForScrollId(xpath);
  }

  static dom.Element? _findByScrollId(
    dom.DocumentFragment root,
    String? scrollId,
  ) {
    if (scrollId == null) return null;

    final elements = root.querySelectorAll(
      '[${HtmlConstants.scrollIdAttribute}]',
    );
    for (final element in elements) {
      if (element.attributes[HtmlConstants.scrollIdAttribute] == scrollId) {
        return element;
      }
    }

    return null;
  }
}
