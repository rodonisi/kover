import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/actions_app_bar/search_button.dart';
import 'package:kover/widgets/actions_app_bar/sync_button.dart';

class ActionsAppBar extends StatelessWidget {
  const ActionsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      forceMaterialTransparency: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      actionsPadding: LayoutConstants.smallerEdgeInsets,
      actions: [
        _ActionsBar(),
      ],
    );
  }
}

class _ActionsBar extends ConsumerWidget {
  const _ActionsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: shape?.copyWith(
        borderRadius: const BorderRadiusGeometry.all(
          Radius.circular(LayoutConstants.mediumBorderRadius),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(LayoutConstants.smallerPadding),
        child: Row(
          spacing: LayoutConstants.smallPadding,
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchButton(),
            SyncButton(),
          ],
        ),
      ),
    );
  }
}
