import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';

class OptionContainer extends StatelessWidget {
  final String title;
  final String? description;
  final String? value;
  final IconData? icon;
  final bool sameRow;
  final Widget child;

  const OptionContainer({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.value,
    this.icon,
    this.sameRow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: .start,
      crossAxisAlignment: .start,
      spacing: LayoutConstants.smallPadding,
      children: [
        Row(
          spacing: LayoutConstants.smallPadding,
          children: [
            Expanded(
              child: Row(
                spacing: LayoutConstants.smallPadding,
                children: [
                  if (icon != null) Icon(icon),
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (description != null)
                    Tooltip(
                      message: description!,
                      triggerMode: .tap,
                      showDuration: 60.minutes,
                      margin: const EdgeInsets.symmetric(
                        horizontal: LayoutConstants.largePadding,
                      ),
                      child: const IconButton(
                        icon: Icon(
                          KoverIcons.info,
                        ),
                        onPressed: null,
                      ),
                    ),
                ],
              ),
            ),
            if (sameRow) child,
            if (value != null)
              Text(
                value!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary,
                ),
              ),
          ],
        ),
        if (!sameRow) child,
      ],
    );
  }
}
