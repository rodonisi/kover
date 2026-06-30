import 'package:flutter/material.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';

class BottomSheetOption extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final Widget Function(BuildContext) bottomSheetBuilder;
  const BottomSheetOption({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.bottomSheetBuilder,
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
      leading: leadingIcon != null ? Icon(leadingIcon) : null,
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailing: const Icon(KoverIcons.chevronRight),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          LayoutConstants.smallerBorderRadius,
        ),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            maxWidth: LayoutBreakpoints.medium,
          ),
          builder: bottomSheetBuilder,
        );
      },
    );
  }
}
