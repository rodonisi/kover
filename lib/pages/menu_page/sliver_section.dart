import 'package:flutter/material.dart';
import 'package:kover/utils/layout_constants.dart';

class SliverSection extends StatelessWidget {
  final String title;

  const SliverSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: LayoutConstants.mediumEdgeInsets,
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
