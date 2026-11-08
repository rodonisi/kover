import 'package:equatable/equatable.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';

/// The source range rendered as one subpage.
class const EpubSubpage({
  /// First position included in the subpage, or null when it starts at the
  /// beginning of the document.
  final EpubPosition? start,

  /// First position not included in the subpage, or null when it runs to the
  /// end of the document.
  final EpubPosition? end,

  /// True when [start] continues a block that started on a previous subpage.
  final bool startsMidBlock = false,
}) extends Equatable {
  @override
  List<Object?> get props => [start, end, startsMidBlock];
}
