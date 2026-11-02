import 'package:equatable/equatable.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';

/// Settings consumed by the paginated EPUB rendering pipeline.
class const PaginatedEpubPageSettings({
  required final double horizontalMarginSize,
  required final double verticalMarginSize,
  required final double fontSize,
  required final double paragraphSpacing,
  required final double lineHeight,
  required final double wordSpacing,
  required final double letterSpacing,
  required final String? fontFamily,
  required final bool removeParagraphIndent,
  required final bool highlightResumePoint,
  required final bool canScroll,
  required final bool reduceAnimations,
  required final EpubTextAlignment textAlignment,
  required final EpubReaderMode mode,
}) extends Equatable {
  @override
  List<Object?> get props => [
    horizontalMarginSize,
    verticalMarginSize,
    fontSize,
    paragraphSpacing,
    lineHeight,
    wordSpacing,
    letterSpacing,
    fontFamily,
    removeParagraphIndent,
    highlightResumePoint,
    canScroll,
    reduceAnimations,
    textAlignment,
    mode,
  ];
}
