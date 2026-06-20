import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class ReadDirectionOption extends ConsumerWidget {
  final int seriesId;

  const ReadDirectionOption({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = commonReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(provider),
      data: (settings) {
        return ChoiceOption<ReadDirection>(
          title: l.readingDirection,
          icon: switch (settings.readDirection) {
            .leftToRight => KoverIcons.ltr,
            .rightToLeft => KoverIcons.rtl,
          },
          value: settings.readDirection,
          options: [
            ChoiceOptionEntry(
              value: .leftToRight,
              label: l.leftToRight,
              icon: KoverIcons.ltr,
            ),
            ChoiceOptionEntry(
              value: .rightToLeft,
              label: l.rightToLeft,
              icon: KoverIcons.rtl,
            ),
          ],
          onChanged: (newValue) async {
            await ref.read(provider.notifier).setReadDirection(newValue);
          },
        );
      },
    );
  }
}
