import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';

/// A single measured unit produced by the measurement pass.
sealed class const EpubMeasureUnit({
  /// Position where this unit starts in the source tree.
  required final EpubPosition start,

  /// Source element index this unit belongs to.
  required final int nodeIndex,

  /// Top position of the unit in the viewport.
  required final double top,

  /// Bottom position of the unit in the viewport.
  required final double bottom,

  /// Extra space preserved when this unit starts a subpage.
  final double topInset = 0,

  /// Extra space preserved when this unit ends a subpage.
  final double bottomInset = 0,
}) {
  double get height => bottom - top;
  double get pageStartTop => top - topInset;
  double get pageEndBottom => bottom + bottomInset;
}

/// A line of text. [start] points at the first character of the line.
final class const EpubLineUnit({
  required super.start,
  required super.nodeIndex,
  required super.top,
  required super.bottom,
  super.topInset,
  super.bottomInset,
}) extends EpubMeasureUnit;

/// Content that cannot be split: image, table, rule, empty block, etc.
final class const EpubLeafUnit({
  required super.start,
  required super.nodeIndex,
  required super.top,
  required super.bottom,
  super.topInset,
  super.bottomInset,
}) extends EpubMeasureUnit;
