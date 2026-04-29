import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/download_settings.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DataManagementSettings extends ConsumerWidget {
  const DataManagementSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(downloadSettingsProvider);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Async(
          asyncValue: settings,
          data: (data) => Column(
            mainAxisSize: .min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: LayoutConstants.largePadding,
            children: [
              Text(
                'Data Management',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              BooleanOption(
                title: 'Automatically Download Covers',
                description:
                    'If disabled, covers will only be downloaded together with chapters.\n'
                    'Covers will still be fetched from the server if not downloaded and a connection is available.',
                icon: LucideIcons.imageDownDir,
                value: data.downloadCovers,
                onChanged: (value) async {
                  await ref
                      .read(downloadSettingsProvider.notifier)
                      .setDownloadCovers(value);
                },
              ),
              NumericOption(
                title: 'Max Concurrent Downloads',
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
              const DatabaseSize(),
            ],
          ),
        ),
      ),
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
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .start,
      children: [
        Text('Database Size: ', style: Theme.of(context).textTheme.labelMedium),
        Async(
          asyncValue: ref.watch(databaseSizeProvider),
          data: (size) {
            return Text(
              _formatSize(size),
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
