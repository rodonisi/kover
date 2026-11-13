import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/utils/constants/html_constants.dart';

part 'epub_position.freezed.dart';

/// A position inside the source document tree.
///
/// [blockNodeIndex] is the [HtmlConstants.nodeIndexAttribute] element index.
/// [childPath] addresses the node under that element using `childNodes`
/// indices. An empty [childPath] points at the start of the block itself.
@freezed
class const EpubPosition({
  required final int blockNodeIndex,
  final List<int> childPath = const [],
  final int offset = 0,

  /// When true the position sits after the referenced node (used for `<br>`).
  final bool afterNode = false,
}) with _$EpubPosition;
