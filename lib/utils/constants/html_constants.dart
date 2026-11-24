sealed class HtmlConstants {
  // Kover-specific constants
  static const String koverWrapperClass = 'kover-content';
  static const String resumeParagraphClass = 'kover-resume-paragraph';
  static const String nodeIndexAttribute = 'kover-node-index';
  static const String scrollIdAttribute = 'kover-scroll-id';
  static const String textIndentAttribute = 'kover-text-indent';
  static const String startsMidBlockAttribute = 'kover-starts-mid-block';
  static const String trimStartAttribute = 'kover-trim-start';
  static const String trimEndAttribute = 'kover-trim-end';

  // Kavita-specific constants
  static const String kavitaWrapperClass = 'book-content';
  static const String kavitaPageAttribute = 'kavita-page';
  static const String kavitaPartAttribute = 'kavita-part';
  static const String kavitaNoteRefAttribute = 'kavita-note-ref';
  static const String kavitaHighlightElementTag = 'app-epub-highlight';
  static const String kavitaAnnotationIdAttribute = 'data-annotation-id';

  // Annotation highlight constants
  static const String koverAnnotationIdAttribute = 'data-kover-annotation-id';
  static const String annotationHighlightIdPrefix = 'epub-highlight-';

  /// The canonical DOM id for the highlight belonging to [localId].
  static String annotationHighlightId(int localId) =>
      '$annotationHighlightIdPrefix$localId';

  /// Reads the server annotation id from Kavita's highlight attributes.
  ///
  /// Supports both the current `id` format and the older data attribute.
  static int? annotationServerId(Map<Object, String> attributes) {
    final dataId = attributes[kavitaAnnotationIdAttribute]?.trim();
    if (dataId case final dataId?) {
      final parsed = int.tryParse(dataId);
      if (parsed != null) return parsed;
    }

    final id = attributes['id']?.trim();
    if (id == null || !id.startsWith(annotationHighlightIdPrefix)) return null;

    return int.tryParse(id.substring(annotationHighlightIdPrefix.length));
  }
}
