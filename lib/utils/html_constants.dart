sealed class HtmlConstants {
  static const String scrollIdAttribute = 'scroll-id';
  static const String resumeParagraphClass = 'resume-paragraph';
  static const String kavitaWrapperClass = 'book-content';
  static const String koverWrapperClass = 'kover-content';
  static const String textIndentSpanAttribute = 'indent-span';
  static const String splitParagraphAttribute = 'split-paragraph';

  /// Tag Kavita wraps around highlighted text when serving epub pages.
  static const String highlightTag = 'app-epub-highlight';

  /// Prefix of the highlight element id, followed by the annotation id.
  static const String highlightIdPrefix = 'epub-highlight-';
}
