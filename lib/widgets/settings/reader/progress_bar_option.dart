import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class ProgressBarOption extends ConsumerWidget {
  final int seriesId;
  const ProgressBarOption({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = commonReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(provider),
      data: (settings) {
        return BooleanOption(
          icon: KoverIcons.progressBar,
          title: l.showProgressBar,
          value: settings.showProgressBar,
          onChanged: (value) async {
            await ref.read(provider.notifier).setShowProgressBar(value);
          },
        );
      },
    );
  }
}
