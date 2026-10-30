import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_break.dart';

/// A single break unit produced by the measurement pass.
sealed class const EpubBreakUnit({
  /// Boundary that starts the page containing this unit.
  required final EpubBreak start,

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
}) extends EpubBreakUnit;

/// Content that cannot be split: image, table, rule, empty block...
final class const EpubLeafUnit({
  required super.start,
  required super.nodeIndex,
  required super.top,
  required super.bottom,
  super.topInset,
  super.bottomInset,
}) extends EpubBreakUnit;
