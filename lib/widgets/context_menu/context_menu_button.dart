import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:kover/utils/layout_constants.dart';

class ContextMenuButton extends StatelessWidget {
  final Widget icon;
  final ContextMenu menu;
  const ContextMenuButton({
    super.key,
    required this.icon,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTapUp: (details) async {
        await showContextMenu(
          context,
          contextMenu: menu.copyWith(position: details.globalPosition),
        );
      },
      child: Padding(
        padding: LayoutConstants.smallEdgeInsets,
        child: icon,
      ),
    );
  }
}
