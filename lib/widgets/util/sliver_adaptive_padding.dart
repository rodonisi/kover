import 'package:flutter/widgets.dart';
import 'package:kover/utils/layout_constants.dart';

/// A sliver widget that lets the child sliver grow to a [maxWidth], adding
/// padding when the viewport is larger than that.
class SliverAdaptivePadding extends StatelessWidget {
  final double maxWidth;
  final Widget sliver;

  const new({
    super.key,
    required this.sliver,
    this.maxWidth = LayoutConstants.listMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final side =
            (constraints.crossAxisExtent - maxWidth).clamp(
              0,
              double.infinity,
            ) /
            2;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: sliver,
        );
      },
    );
  }
}
