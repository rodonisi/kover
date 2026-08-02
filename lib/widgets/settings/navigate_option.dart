import 'package:flutter/material.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';

class NavigateOption extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final VoidCallback? onTap;

  const NavigateOption({
    super.key,
    required this.title,
    required this.leadingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.smallerPadding,
        ),
        child: Text(title),
      ),
      titleTextStyle: Theme.of(context).textTheme.titleSmall,
      horizontalTitleGap: LayoutConstants.smallPadding,
      visualDensity: VisualDensity.compact,
      leading: leadingIcon != null ? Icon(leadingIcon) : null,
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailing: const Icon(KoverIcons.chevronRight),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          LayoutConstants.smallerBorderRadius,
        ),
      ),
      onTap: onTap,
    );
  }
}
