import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/layout_constants.dart';

class MonitoringOptOutPopup extends ConsumerWidget {
  const MonitoringOptOutPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Send anonymous crash reports and diagnostics?'),
      content: const Column(
        spacing: LayoutConstants.mediumPadding,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Text(
            'Help improve the app by sending anonymous error and '
            'performance statistics. The data does not contain any '
            'personal information and is uniquely used to improve '
            'the app.',
          ),
          Text('This can be changed in the settings at any time.'),
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
          child: const Text('No, thanks'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(generalSettingsProvider.notifier).setSendDiagnostics(true);
            Navigator.of(context).pop();
          },
          child: const Text('I\'m in!'),
        ),
      ],
    );
  }
}
