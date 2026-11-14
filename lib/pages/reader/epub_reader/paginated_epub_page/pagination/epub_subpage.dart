import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/measure/epub_position.dart';

part 'epub_subpage.freezed.dart';

/// The source range rendered as one subpage.
@freezed
class const EpubSubpage({
  /// First position included in the subpage, or null when it starts at the
  /// beginning of the document.
  final EpubPosition? start,

  /// First position not included in the subpage, or null when it runs to the
  /// end of the document.
  final EpubPosition? end,

  /// True when [start] continues a block that started on a previous subpage.
  final bool startsMidBlock = false,
}) with _$EpubSubpage;
