import 'package:flutter/material.dart';
import 'package:kover/utils/layout_constants.dart';

class SliverBottomPadding extends StatelessWidget {
  const SliverBottomPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: ListBottomPadding(),
    );
  }
}

class ListBottomPadding extends StatelessWidget {
  const ListBottomPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          LayoutConstants.mediumPadding + MediaQuery.of(context).padding.bottom,
    );
  }
}
