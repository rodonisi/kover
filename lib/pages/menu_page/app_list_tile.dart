import 'package:flutter/material.dart';
import 'package:kover/utils/layout_constants.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.icon,
    this.onTap,
  });

  final String title;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      clipBehavior: .antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.mediumPadding,
          vertical: LayoutConstants.smallPadding,
        ),
        leading: icon != null
            ? CircleAvatar(
                child: icon,
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
