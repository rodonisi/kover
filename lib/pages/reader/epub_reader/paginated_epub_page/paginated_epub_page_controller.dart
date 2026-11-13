import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/pagination/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/resume_highlight_operation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:material_ui/material_ui.dart';

enum PaginatedEpubPageControllerStatus { measuring, ready }

/// Controls the state of a [PaginatedEpubPage].
class PaginatedEpubPageController({
  final void Function(int subpage, String? scrollId)? onSubpageChanged,

  /// Called when pagination restores a position instead of the user moving.
  ///
  /// Falls back to [onSubpageChanged] when not provided.
  final void Function(int subpage, String? scrollId)? onSubpageRestored,
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
  String? _pendingAnchor;
  PaginatedEpubPageSettings? _settings;
  Object? _measuredLayoutKey;

  PaginatedEpubPageControllerStatus get status => _status;
  dom.DocumentFragment? get root => _paginator?.root;
  Size? get contentViewport => _contentViewport;
  String? get initialXpath => _initialXpath;

  int get currentSubpage => _currentSubpage;
  int get subpageCount => _paginator?.subpageCount ?? 0;
  CssEngine get cssEngine =>
      _cssEngine ?? (throw Exception('CSS engine is not initialized'));

  /// Move to the next subpage if available.
  void nextSubpage() {
    jumpToSubpage(_currentSubpage + 1);
  }

  /// Move to the previous subpage if available.
  void previousSubpage() {
    jumpToSubpage(_currentSubpage - 1);
  }

  /// Jump to the subpage at [index].
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

  /// Jumps to the subpage containing [anchor].
  ///
  /// If the page is still measuring, the anchor is kept and applied once
  /// pagination completes.
  void jumpToAnchor(String anchor) {
    if (_status != .ready) {
      _pendingAnchor = anchor;
      return;
    }

    _jumpToAnchor(anchor);
  }

  /// Sets the subpage to use as soon as pagination completes.
  ///
  /// Used while a page is still measuring and the caller already knows which
  /// subpage should become visible.
  void setPendingSubpage(int? subpage) {
    _pendingSubpage = subpage;
  }

  /// Attach a root HTML document fragment to the controller.
  /// This causes the controller to reset its state and start measuring the
  /// provided HTML content.
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
    _settings = settings;
    _initialXpath = initialXpath;
    _highlightedElement = settings.highlightResumePoint
        ? _findByScrollId(root, initialXpath)
        : null;
    _resumePending = initialXpath != null;
    _currentSubpage = 0;
    _contentViewport = null;
    _measuredLayoutKey = null;
    _status = .measuring;
    notifyListeners();
  }

  /// Updates the additional CSS styles.
  void updateStyles(Map<String, Map<String, String>> additionalStyles) {
    _cssEngine?.updateAdditionalStyles(additionalStyles);
    notifyListeners();
  }

  /// Updates the settings used to render the page.
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

    _cssEngine?.invalidate();
    _paginator?.invalidateSubpageCache();
    notifyListeners();
  }

  /// Update the viewport size used for pagination.
  void updateViewport(Size viewport) {
    if (_contentViewport == viewport) return;

    _contentViewport = viewport;
    if (_status == .measuring) return;

    _status = .measuring;
    notifyListeners();
  }

  /// Forces the controller to remeasure the content.
  void remeasure() {
    if (_measuredLayoutKey == _settings?.layoutKey) return;

    _status = .measuring;
    notifyListeners();
  }

  /// Processes the measurements collected from the content.
  void processMeasurements(
    EpubMeasurements measurements, {
    required Size viewport,
    Object? layoutKey,
  }) {
    final paginator = _paginator;
    if (paginator == null) return;
    if (layoutKey != null && layoutKey != _settings?.layoutKey) return;

    paginator.paginate(measurements.units, viewport.height);
    _contentViewport = viewport;
    _measuredLayoutKey = _settings?.layoutKey;
    _status = .ready;

    final anchorSubpage = _takePendingAnchorSubpage();
    final count = paginator.subpageCount;
    onSubpagesCountChanged?.call(count);

    final pendingSubpage = _pendingSubpage;
    _pendingSubpage = null;
    final target =
        anchorSubpage ??
        (_resumePending
            ? _resumeSubpage() ?? 0
            : pendingSubpage ?? _currentSubpage);
    _resumePending = false;
    _currentSubpage = count == 0 ? 0 : target.clamp(0, count - 1);

    // With no subpages there is no position to report. Calling this with 0
    // would make the navigation provider treat it as past the last subpage.
    if (count > 0) {
      (onSubpageRestored ?? onSubpageChanged)?.call(
        _currentSubpage,
        scrollIdForSubpage(_currentSubpage),
      );
    }
    notifyListeners();
  }

  String getSubpage(int index) {
    if (_paginator == null) throw Exception('Paginator is not initialized');
    return _paginator!.getSubpage(index);
  }

  String? scrollIdForSubpage(int index) {
    return _paginator?.scrollIdForSubpage(index);
  }

  /// Returns the subpage that contains the element with [anchor].
  ///
  /// The lookup first uses the element's injected scroll id, then falls back to
  /// the element id in the serialized subpages.
  int? subpageForAnchor(String anchor) {
    final paginator = _paginator;
    final root = paginator?.root;
    if (paginator == null || root == null) return null;

    final id = anchor.startsWith('#') ? anchor.substring(1) : anchor;
    if (id.isEmpty) return null;

    final element = root.findByAttribute('id', id);
    final scrollId = element?.attributes[HtmlConstants.scrollIdAttribute];
    if (scrollId != null) {
      final subpage = paginator.subpageForScrollId(scrollId);
      if (subpage != null) return subpage;
    }

    return paginator.subpageForElementId(id);
  }

  void _jumpToAnchor(String anchor) {
    final subpage = subpageForAnchor(anchor);
    if (subpage != null) {
      jumpToSubpage(subpage);
    }
  }

  int? _takePendingAnchorSubpage() {
    final anchor = _pendingAnchor;
    if (anchor == null) return null;

    _pendingAnchor = null;
    return subpageForAnchor(anchor);
  }

  int? _resumeSubpage() {
    final paginator = _paginator;
    final xpath = _initialXpath;
    if (paginator == null || xpath == null) return null;

    return paginator.subpageForScrollId(xpath);
  }

  static dom.Element? _findByScrollId(
    dom.DocumentFragment root,
    String? scrollId,
  ) {
    if (scrollId == null) return null;

    return root.findByAttribute(HtmlConstants.scrollIdAttribute, scrollId);
  }
}

class PaginatedEpubPageControllerHook
    extends Hook<PaginatedEpubPageController> {
  final void Function(int subpage, String? scrollId)? onSubpageChanged;
  final void Function(int subpage, String? scrollId)? onSubpageRestored;
  final void Function(int)? onSubpagesCountChanged;

  const PaginatedEpubPageControllerHook({
    super.keys,
    this.onSubpageChanged,
    this.onSubpageRestored,
    this.onSubpagesCountChanged,
  });

  @override
  PaginatedEpubPageControllerHookState createState() =>
      PaginatedEpubPageControllerHookState();
}

class PaginatedEpubPageControllerHookState
    extends
        HookState<
          PaginatedEpubPageController,
          PaginatedEpubPageControllerHook
        > {
  late final PaginatedEpubPageController controller;

  @override
  void initHook() {
    super.initHook();
    controller = PaginatedEpubPageController(
      onSubpageChanged: (subpage, scrollId) =>
          hook.onSubpageChanged?.call(subpage, scrollId),
      onSubpageRestored: (subpage, scrollId) =>
          hook.onSubpageRestored?.call(subpage, scrollId),
      onSubpagesCountChanged: (count) =>
          hook.onSubpagesCountChanged?.call(count),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  PaginatedEpubPageController build(BuildContext context) => controller;
}

PaginatedEpubPageController usePaginatedEpubPageController({
  List<Object?>? keys,
  void Function(int subpage, String? scrollId)? onSubpageChanged,
  void Function(int subpage, String? scrollId)? onSubpageRestored,
  void Function(int)? onSubpagesCountChanged,
}) => use(
  PaginatedEpubPageControllerHook(
    keys: keys,
    onSubpageChanged: onSubpageChanged,
    onSubpageRestored: onSubpageRestored,
    onSubpagesCountChanged: onSubpagesCountChanged,
  ),
);
