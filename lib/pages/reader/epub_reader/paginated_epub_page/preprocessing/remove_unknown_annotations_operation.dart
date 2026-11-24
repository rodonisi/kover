import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/epub_page_preprocessor_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

/// Removes annotation highlights that Kavita injected for annotations that no
/// longer exist locally.
///
/// Only highlights carrying a known server id are kept. Kover's own id
/// attribute is written later by `EnsureAnnotationsOperation`, so it is not
/// consulted here.
final class RemoveUnknownAnnotationsOperation
    extends EpubPagePreprocessorOperation {
  RemoveUnknownAnnotationsOperation({required this.annotations});

  final Iterable<PaginatedEpubAnnotation> annotations;

  final _serverIds = <int>{};

  @override
  void start(dom.DocumentFragment root) {
    _serverIds
      ..clear()
      ..addAll(annotations.map((annotation) => annotation.serverId).nonNulls);
  }

  @override
  void enter(dom.Element element) {
    if (element.localName != HtmlConstants.kavitaHighlightElementTag) return;

    final serverId = HtmlConstants.annotationServerId(element.attributes);

    if (serverId != null && _serverIds.contains(serverId)) return;

    _unwrap(element);
  }

  static void _unwrap(dom.Element element) {
    final parent = element.parent;
    if (parent == null) return;

    for (final node in element.nodes.toList(growable: false)) {
      parent.insertBefore(node, element);
    }

    element.remove();
  }
}
