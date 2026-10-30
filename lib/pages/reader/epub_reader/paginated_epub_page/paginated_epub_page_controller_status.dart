import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/epub_paginator.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_measurements_collector.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/node_indexing_operation.dart';
import 'package:material_ui/material_ui.dart';

enum PaginatedEpubPageControllerStatus { measuring, ready }

/// Controls the state of a [PaginatedEpubPage].
class PaginatedEpubPageController({
  final String? initialXpath,
  final void Function(int)? onSubpageChanged,
  final void Function(int)? onSubpagesCountChanged,
}) extends ChangeNotifier {
  EpubPaginator? _paginator;
  PaginatedEpubPageControllerStatus _status = .measuring;
  int _currentSubpage = 0;

  PaginatedEpubPageControllerStatus get status => _status;
  dom.DocumentFragment? get root => _paginator?.root;

  int get currentSubpage => _currentSubpage;
  int get subpageCount => _paginator?.subpageCount ?? 0;

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
    onSubpageChanged?.call(_currentSubpage);
    notifyListeners();
  }

  void attachRoot(dom.DocumentFragment html) {
    final preprocessed = EpubPagePreprocessor(
      root: html,
      operations: [NodeIndexingOperation()],
    ).process();
    _paginator = EpubPaginator(root: preprocessed);
    _currentSubpage = 0;
    _status = .measuring;
    notifyListeners();
  }

  void processMeasurements(
    EpubMeasurements measurements, {
    required double pageHeight,
  }) {
    final paginator = _paginator;
    if (paginator == null) return;

    paginator.paginate(measurements.units, pageHeight);

    final count = paginator.subpageCount;
    _currentSubpage = count == 0 ? 0 : _currentSubpage.clamp(0, count - 1);
    _status = .ready;
    onSubpagesCountChanged?.call(count);
    notifyListeners();
  }

  void viewportChanged() {
    if (_status == .measuring) return;

    _status = .measuring;
    notifyListeners();
  }

  String getSubpage(int index) {
    if (_paginator == null) throw Exception('Paginator is not initialized');
    return _paginator!.getSubpage(index);
  }
}
