import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class OrientationOption extends ConsumerWidget {
  final int seriesId;

  const OrientationOption({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = commonReaderSettingsProvider(seriesId: seriesId);
    final orientation = ref.watch(
      settings.select(
        (state) => state.whenData((value) => value.orientationLock),
      ),
    );

    return Async(
      asyncValue: orientation,
      data: (data) {
        return ChoiceOption<OrientationLock>(
          title: l.orientation,
          icon: switch (data) {
            .none => KoverIcons.unlockedOrientation,
            .portrait => KoverIcons.portrait,
            .landscape => KoverIcons.landscape,
          },
          value: data,
          options: [
            ChoiceOptionEntry(
              value: .none,
              label: l.system,
              icon: KoverIcons.unlockedOrientation,
            ),
            ChoiceOptionEntry(
              value: .portrait,
              label: l.portrait,
              icon: KoverIcons.portrait,
            ),
            ChoiceOptionEntry(
              value: .landscape,
              label: l.landscape,
              icon: KoverIcons.landscape,
            ),
          ],
          onChanged: (newValue) async {
            await ref.read(settings.notifier).setOrientationLock(newValue);
          },
        );
      },
    );
  }
}
