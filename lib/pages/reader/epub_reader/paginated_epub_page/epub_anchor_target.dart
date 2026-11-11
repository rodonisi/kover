import 'package:html/dom.dart' as dom;
import 'package:kover/utils/constants/html_constants.dart';

/// A navigation target encoded on an EPUB anchor.
///
/// Kavita rewrites internal EPUB links before serving the page:
///
/// - cross-page links get `kavita-page` and optionally `kavita-part`
/// - footnote references get `kavita-note-ref`
/// - links that stay on the current page keep a `#fragment` href
/// - external links keep their original `http(s)` href
class EpubAnchorTarget {
  const EpubAnchorTarget({
    this.page,
    this.part,
    this.externalUri,
  });

  /// Zero-based reading-order page within the current chapter.
  final int? page;

  /// Fragment id on [page].
  ///
  /// The backend also uses this attribute for the original file path when it
  /// could not resolve a page mapping. In that case no element will match and
  /// the reader lands at the start of [page].
  final String? part;

  /// External URL that should be opened outside the reader.
  final Uri? externalUri;

  /// Builds a target from the attributes Kavita writes on an `<a>` element.
  static EpubAnchorTarget? fromElement(dom.Element element) {
    if (element.localName != 'a') return null;

    final attributes = element.attributes;
    final href = attributes['href'];
    final page = int.tryParse(
      attributes[HtmlConstants.kavitaPageAttribute] ?? '',
    );
    final noteRef = attributes[HtmlConstants.kavitaNoteRefAttribute];
    final part =
        _normalizePart(noteRef) ??
        _normalizePart(attributes[HtmlConstants.kavitaPartAttribute]) ??
        _normalizePart(href?.startsWith('#') == true ? href : null);

    if (part != null) {
      return EpubAnchorTarget(page: page, part: part);
    }

    if (page != null) {
      return EpubAnchorTarget(page: page);
    }

    if (href == null) return null;

    final external = _externalUri(href);
    if (external != null) {
      return EpubAnchorTarget(externalUri: external);
    }

    return null;
  }

  static String? _normalizePart(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;
    return withoutHash.isEmpty ? null : withoutHash;
  }

  static Uri? _externalUri(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return switch (uri.scheme.toLowerCase()) {
        'http' || 'https' || 'mailto' || 'tel' => uri,
        _ => null,
      };
    }

    if (uri.hasAuthority) {
      return Uri(scheme: 'https').resolveUri(uri);
    }

    return null;
  }
}
