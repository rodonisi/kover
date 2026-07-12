import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: LayoutConstants.largePadding,
          children: [
            Text(
              l.appearance,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const _ThemeMode(),
            const _OutlinedTheme(),
            const _ReduceAnimations(),
          ],
        ),
      ),
    );
  }
}

class _ThemeMode extends ConsumerWidget {
  const _ThemeMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider);

    return Async(
      asyncValue: theme,
      data: (theme) => ChoiceOption<ThemeMode>(
        title: l.themeMode,
        options: [
          ChoiceOptionEntry(
            value: .system,
            label: l.system,
            icon: KoverIcons.systemTheme,
          ),
          ChoiceOptionEntry(
            value: .light,
            label: l.light,
            icon: KoverIcons.lightTheme,
          ),
          ChoiceOptionEntry(
            value: .dark,
            label: l.dark,
            icon: KoverIcons.darkTheme,
          ),
        ],
        value: theme.mode,
        onChanged: (newValue) async {
          await ref.read(themeProvider.notifier).setMode(newValue);
        },
      ),
    );
  }
}

class _OutlinedTheme extends ConsumerWidget {
  const _OutlinedTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider);

    return Async(
      asyncValue: theme,
      data: (theme) => BooleanOption(
        title: l.outlinedTheme,
        icon: KoverIcons.outline,
        value: theme.outlined,
        onChanged: (value) =>
            ref.read(themeProvider.notifier).setOutlined(value),
      ),
    );
  }
}

class _ReduceAnimations extends ConsumerWidget {
  const _ReduceAnimations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider);

    return Async(
      asyncValue: theme,
      data: (theme) => BooleanOption(
        icon: KoverIcons.animation,
        title: l.reduceAnimations,
        description: l.reduceAnimationsDescription,
        value: theme.reduceAnimations,
        onChanged: (value) =>
            ref.read(themeProvider.notifier).setReduceAnimations(value),
      ),
    );
  }
}
