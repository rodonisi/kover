import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/reader_dim_settings.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DimOption extends ConsumerWidget {
  const DimOption({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dimLevel =
        ref.watch(readerDimSettingsProvider).valueOrNull?.dimLevel ?? 0.0;

    return NumericOption(
      title: 'Screen Dimming',
      icon: LucideIcons.sunMedium,
      value: dimLevel * 100,
      min: 0,
      max: 90,
      step: ReaderDimSettingsLimits.dimStep,
      decimalPlaces: 0,
      onChanged: (newValue) =>
          ref.read(readerDimSettingsProvider.notifier).setDimLevel(newValue / 100),
    );
  }
}
