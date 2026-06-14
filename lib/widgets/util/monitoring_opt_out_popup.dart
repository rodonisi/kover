import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/layout_constants.dart';

class MonitoringOptOutPopup extends ConsumerWidget {
  const MonitoringOptOutPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.sendDiagnosticsDialogTitle),
      content: Column(
        spacing: LayoutConstants.mediumPadding,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Text(l.sendDiagnosticsDescription),
          Text(l.sendDiagnosticsChangeable),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            ref
                .read(generalSettingsProvider.notifier)
                .setSendDiagnostics(false);
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.error,
            foregroundColor: Theme.of(
              context,
            ).colorScheme.onError,
          ),
          child: Text(l.noThanks),
        ),
        FilledButton(
          onPressed: () {
            ref.read(generalSettingsProvider.notifier).setSendDiagnostics(true);
            Navigator.of(context).pop();
          },
          child: Text(l.imIn),
        ),
      ],
    );
  }
}
