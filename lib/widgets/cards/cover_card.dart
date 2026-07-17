import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';

class CoverCard extends ConsumerWidget {
  final String? title;
  final Icon? icon;
  final String? actionLabel;
  final Icon actionIcon;
  final Icon actionDisabledIcon;
  final bool actionDisabled;
  final double progress;
  final Widget coverImage;
  final Widget? downloadStatusIcon;
  final void Function()? onTap;
  final void Function()? onActionTap;

  const CoverCard({
    super.key,
    this.title,
    this.icon,
    this.actionLabel,
    this.actionIcon = const Icon(KoverIcons.read),
    this.actionDisabledIcon = const Icon(KoverIcons.noConnection),
    this.actionDisabled = true,
    required this.coverImage,
    this.downloadStatusIcon,
    this.onTap,
    this.onActionTap,
    double? progress,
  }) : progress = progress ?? 0.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final effectiveLabel = actionLabel ?? l.read;

    return Card.filled(
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: coverImage,
                  ),
                  if (progress <= 0)
                    Align(
                      alignment: .topRight,
                      child: Transform.translate(
                        offset: const Offset(20, -20),
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: Container(
                            width: 40,
                            height: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  if (onActionTap != null)
                    Align(
                      alignment: .bottomCenter,
                      child: Padding(
                        padding: LayoutConstants.smallEdgeInsets,
                        child: actionDisabled
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: FilledButton.icon(
                                    icon: actionDisabledIcon,
                                    label: FittedBox(
                                      child: Text(effectiveLabel),
                                    ),
                                    onPressed: null,
                                  ),
                                ),
                              )
                            : FilledButton.icon(
                                icon: actionIcon,
                                label: FittedBox(child: Text(effectiveLabel)),
                                onPressed: onActionTap,
                              ),
                      ),
                    ),
                  if (downloadStatusIcon != null)
                    Align(
                      alignment: .topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: downloadStatusIcon,
                      ),
                    ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
            ),
            if (title != null)
              Padding(
                padding: LayoutConstants.smallEdgeInsets,
                child: Row(
                  mainAxisSize: .min,
                  spacing: LayoutConstants.smallPadding,
                  children: [
                    ?icon,
                    Expanded(
                      child: Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
