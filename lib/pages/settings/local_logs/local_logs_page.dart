import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/log_entry.dart';
import 'package:kover/riverpod/providers/local_log.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/sentry.dart';

class LocalLogsPage extends HookConsumerWidget {
  const LocalLogsPage({super.key});

  LogEntry _scrubEntry(LogEntry entry) => entry.copyWith(
    message: scrubLooseUrls(entry.message),
    error: entry.error != null ? scrubLooseUrls(entry.error!) : null,
  );

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context).copiedToClipboard),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scrubbed = useState(true);
    final logs = ref.watch(localLogProvider);

    final entries = logs.value?.entries ?? const <LogEntry>[];
    final scrubbedEntries = useMemoized(
      () => entries.map(_scrubEntry).toList(),
      [entries],
    );
    final displayed = (scrubbed.value ? scrubbedEntries : entries).reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.logs),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.smallPadding,
        ),
        actions: [
          IconButton(
            icon: const Icon(KoverIcons.copy),
            onPressed: () => _copyToClipboard(
              context,
              jsonEncode(displayed.map((e) => e.toJson()).toList()),
            ),
          ),
          IconButton(
            icon: Icon(
              scrubbed.value ? KoverIcons.hidden : KoverIcons.visible,
            ),
            onPressed: () {
              scrubbed.value = !scrubbed.value;
            },
          ),
        ],
      ),

      body: ListView.separated(
        itemCount: displayed.length,
        itemBuilder: (context, index) {
          final entry = displayed[index];
          final text = jsonEncode(entry.toJson());

          return InkWell(
            onTap: () => _copyToClipboard(context, text),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.smallPadding,
                horizontal: LayoutConstants.mediumPadding,
              ),
              child: Row(
                spacing: LayoutConstants.mediumPadding,
                children: [
                  Icon(
                    switch (entry.level) {
                      .debug => KoverIcons.debug,
                      .info => KoverIcons.info,
                      .warning => KoverIcons.warning,
                      .error => KoverIcons.error,
                      .fatal => KoverIcons.fatal,
                    },
                    color: switch (entry.level) {
                      .info => theme.colorScheme.primary,
                      .warning => Colors.orange,
                      .error || .fatal => theme.colorScheme.error,
                      _ => null,
                    },
                  ),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (context, index) =>
            const SizedBox(height: LayoutConstants.smallPadding),
      ),
    );
  }
}
