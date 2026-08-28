import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/keybind_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class KeybindsSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Card(
      margin: .zero,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: LayoutConstants.largePadding,
          children: [
            Text(
              l.keybinds,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const _Keybinds(),
          ],
        ),
      ),
    );
  }
}

class _Keybinds extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final keybindsSettings = ref.watch(keybindsSettingsProvider);

    return Async(
      asyncValue: keybindsSettings,
      data: (data) {
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: LayoutConstants.largePadding,
          children: [
            KeybindOption(
              title: l.keybindNextPage,
              icon: KoverIcons.readingDirectionLTR,
              value: data.nextPage,
              defaultValue: KeybindsSettingsState.defaultNextPage,
              onChanged: (value) => ref
                  .read(keybindsSettingsProvider.notifier)
                  .setNextPageKey(value),
            ),
            KeybindOption(
              title: l.keybindPreviousPage,
              icon: KoverIcons.readingDirectionRTL,
              value: data.previousPage,
              defaultValue: KeybindsSettingsState.defaultPreviousPage,
              onChanged: (value) => ref
                  .read(keybindsSettingsProvider.notifier)
                  .setPreviousPageKey(value),
            ),
          ],
        );
      },
    );
  }
}
