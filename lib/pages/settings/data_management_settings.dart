import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/download_settings.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DataManagementSettings extends ConsumerWidget {
  const DataManagementSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(downloadSettingsProvider);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Async(
          asyncValue: settings,
          data: (data) => Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: LayoutConstants.largePadding,
            children: [
              Text(
                l.dataManagement,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              BooleanOption(
                title: l.downloadAllCovers,
                description: l.downloadAllCoversDescription,
                icon: LucideIcons.imageDownDir,
                value: data.downloadCovers,
                onChanged: (value) async {
                  await ref
                      .read(downloadSettingsProvider.notifier)
                      .setDownloadCovers(value);
                },
              ),
              NumericOption(
                title: l.maxConcurrentDownloads,
                icon: LucideIcons.download,
                min: 1,
                max: 10,
                step: 1,
                decimalPlaces: 0,
                value: data.concurrentDownloads.toDouble(),
                onChanged: (value) async {
                  await ref
                      .read(downloadSettingsProvider.notifier)
                      .setConcurrentDownloads(value.round());
                },
              ),
              Row(
                mainAxisAlignment: .center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: LayoutConstants.mediumPadding,
                      runSpacing: LayoutConstants.mediumPadding,
                      alignment: .center,
                      children: [
                        DatabaseClearOperationButton(
                          asyncValue: ref.watch(reclaimSpaceProvider),
                          text: l.reclaimSpace,
                          icon: const Icon(LucideIcons.databaseZap),
                          onPressed: () async {
                            await ref
                                .read(reclaimSpaceProvider.notifier)
                                .reclaimSpace();
                          },
                        ),
                        DatabaseClearOperationButton(
                          asyncValue: ref.watch(clearDownloadsProvider),
                          text: l.clearDownloads,
                          icon: const Icon(Icons.file_download_off),
                          onPressed: () async {
                            await ref
                                .read(clearDownloadsProvider.notifier)
                                .clearDownloads();
                          },
                        ),
                        DatabaseClearOperationButton(
                          asyncValue: ref.watch(clearCoversProvider),
                          text: l.clearCovers,
                          icon: const Icon(LucideIcons.imageOff),
                          onPressed: () async {
                            await ref
                                .read(clearCoversProvider.notifier)
                                .clearCovers();
                          },
                        ),
                        DatabaseClearOperationButton(
                          asyncValue: ref.watch(clearDatabaseProvider),
                          text: l.clearDatabase,
                          icon: const Icon(LucideIcons.trash),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text(l.clearDatabaseDialogTitle),
                                  content: Text(l.clearDatabaseDialogContent),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop(false),
                                      child: Text(l.cancel),
                                    ),
                                    FilledButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        foregroundColor:
                                            theme.colorScheme.onError,
                                      ),
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop(true),
                                      child: Text(l.clearDatabase),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed == true) {
                              await ref
                                  .read(clearDatabaseProvider.notifier)
                                  .clearDatabase();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!SafePlatform.isWeb)
                const Row(
                  mainAxisAlignment: .start,
                  children: [
                    DatabaseSize(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DatabaseClearOperationButton extends ConsumerWidget {
  final AsyncValue<ClearOperationStatus> asyncValue;
  final String text;
  final Icon? icon;
  final VoidCallback onPressed;

  const DatabaseClearOperationButton({
    super.key,
    required this.asyncValue,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Async(
      asyncValue: asyncValue,
      data: (status) {
        return switch (status) {
          .idle => FilledButton.icon(
            onPressed: () {
              onPressed();
            },
            icon: icon,
            label: Text(text),
          ),
          .busy => Tooltip(
            message: l.databaseBusy,
            triggerMode: .tap,
            child: FilledButton.icon(
              onPressed: null,
              icon: icon,
              label: Text(text),
            ),
          ),
          .inProgress || .reclaimingSpace => FilledButton.icon(
            onPressed: null,
            icon: const SizedBox.square(
              dimension: LayoutConstants.mediumIcon,
              child: Padding(
                padding: LayoutConstants.smallerEdgeInsets,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            label: Text(text),
          ),
          .error => FilledButton.icon(
            onPressed: () async {
              onPressed();
            },
            icon: Icon(
              LucideIcons.circleX,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(text),
          ),
        };
      },
    );
  }
}

class DatabaseSize extends ConsumerWidget {
  const DatabaseSize({
    super.key,
  });

  String _formatSize(int sizeInBytes) {
    if (sizeInBytes > 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    if (sizeInBytes > 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    if (sizeInBytes > 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    }

    return '$sizeInBytes B';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .start,
      children: [
        Text(
          '${l.databaseSize}: ',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Async(
          asyncValue: ref.watch(databaseSizeProvider),
          data: (size) {
            return Text(
              _formatSize(size ?? 0),
              style: Theme.of(context).textTheme.labelMedium,
            );
          },
          loading: () => const SizedBox.square(
            dimension: LayoutConstants.smallIcon,
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}
