import 'package:equatable/equatable.dart';
import 'package:kover/utils/constants/html_constants.dart';

/// One page boundary. Points at a position inside the source tree.
///
/// [blockNodeIndex] is the [HtmlConstants.nodeIndexAttribute] element index.
/// [childPath] addresses the node under that element using `childNodes`
/// indices. An empty [childPath] points at the start of the block itself.
class const EpubBreak({
  required final int blockNodeIndex,
  final List<int> childPath = const [],
  final int offset = 0,

  /// When true the break sits after the referenced node (used for `<br>`).
  final bool afterNode = false,

  /// When true the page starting at this break continues a block that started
  /// on a previous page.
  final bool startsMidBlock = false,
}) extends Equatable {
  EpubBreak copyWith({bool? startsMidBlock}) => EpubBreak(
    blockNodeIndex: blockNodeIndex,
    childPath: childPath,
    offset: offset,
    afterNode: afterNode,
    startsMidBlock: startsMidBlock ?? this.startsMidBlock,
  );

  @override
  List<Object?> get props => [
    blockNodeIndex,
    childPath,
    offset,
    afterNode,
    startsMidBlock,
  ];
}
