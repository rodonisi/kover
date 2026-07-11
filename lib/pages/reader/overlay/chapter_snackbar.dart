import 'package:flutter/material.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/layout_constants.dart';

class ChapterSnackbar extends StatelessWidget {
  final String title;
  final VoidCallback? onNavigate;
  final VoidCallback? onDismiss;

  const ChapterSnackbar({
    super.key,
    required this.title,
    this.onNavigate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Card.filled(
        margin: LayoutConstants.mediumEdgeInsets,
        child: Padding(
          padding: LayoutConstants.mediumEdgeInsets,
          child: Row(
            mainAxisAlignment: .spaceBetween,
            spacing: LayoutConstants.smallPadding,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: .ellipsis,
                ),
              ),
              if (onDismiss != null)
                TextButton(onPressed: onDismiss, child: Text(l.dismiss)),
              FilledButton(
                onPressed: onNavigate,
                child: Text(l.go),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
