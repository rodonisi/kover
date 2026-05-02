import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GeneralSettings extends ConsumerWidget {
  const GeneralSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

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
                'General',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ChoiceOption(
                title: 'Theme Mode',
                icon: LucideIcons.palette,
                options: const [
                  ChoiceOptionEntry(
                    value: ThemeMode.system,
                    label: 'System',
                    icon: LucideIcons.sunMoon,
                  ),
                  ChoiceOptionEntry(
                    value: ThemeMode.light,
                    label: 'Light',
                    icon: LucideIcons.sun,
                  ),
                  ChoiceOptionEntry(
                    value: ThemeMode.dark,
                    label: 'Dark',
                    icon: LucideIcons.moon,
                  ),
                ],
                value: theme.mode,
                onChanged: (newValue) async {
                  await ref.read(themeProvider.notifier).setMode(newValue);
                },
              ),
              BooleanOption(
                title: 'Outlined Theme',
                icon: LucideIcons.squareDashed,
                value: theme.outlined,
                onChanged: (value) =>
                    ref.read(themeProvider.notifier).setOutlined(value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
