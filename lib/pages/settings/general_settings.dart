import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GeneralSettings extends ConsumerWidget {
  const GeneralSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Async(
          asyncValue: theme,
          data: (theme) => Column(
            mainAxisSize: .min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: LayoutConstants.largePadding,
            children: [
              Text(
                l.general,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ChoiceOption(
                title: l.themeMode,
                icon: LucideIcons.palette,
                options: [
                  ChoiceOptionEntry(
                    value: ThemeMode.system,
                    label: l.system,
                    icon: LucideIcons.sunMoon,
                  ),
                  ChoiceOptionEntry(
                    value: ThemeMode.light,
                    label: l.light,
                    icon: LucideIcons.sun,
                  ),
                  ChoiceOptionEntry(
                    value: ThemeMode.dark,
                    label: l.dark,
                    icon: LucideIcons.moon,
                  ),
                ],
                value: theme.mode,
                onChanged: (newValue) async {
                  await ref.read(themeProvider.notifier).setMode(newValue);
                },
              ),
              BooleanOption(
                title: l.outlinedTheme,
                icon: LucideIcons.squareDashed,
                value: theme.outlined,
                onChanged: (value) =>
                    ref.read(themeProvider.notifier).setOutlined(value),
              ),
              Async(
                asyncValue: generalSettings,
                data: (generalSettings) => BooleanOption(
                  title: l.sendDiagnostics,
                  icon: KoverIcons.analytics,
                  description: l.sendDiagnosticsDescription,
                  value: generalSettings.sendDiagnostics,
                  onChanged: (value) => ref
                      .read(generalSettingsProvider.notifier)
                      .setSendDiagnostics(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
