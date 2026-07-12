import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/settings/navbar_editor.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/select_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class GeneralSettings extends ConsumerWidget {
  const GeneralSettings({super.key});

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
              l.general,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const _Locale(),
            const NavbarEditor(),
            const _SendDiagnostics(),
          ],
        ),
      ),
    );
  }
}

class _Locale extends ConsumerWidget {
  const _Locale();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final generalSettings = ref.watch(generalSettingsProvider);

    return Async(
      asyncValue: generalSettings,
      data: (generalSettings) {
        return SelectOption(
          title: l.language,
          icon: KoverIcons.language,
          value: generalSettings.locale,
          options: [
            SelectOptionEntry(
              value: null,
              label: lookupAppLocalizations(
                Locale(Intl.systemLocale.split('_').first),
              ).system,
            ),
            ...AppLocalizations.supportedLocales
                .where((locale) {
                  final localeLookup = lookupAppLocalizations(locale);
                  final sourceLocale = lookupAppLocalizations(
                    const Locale('en'),
                  );
                  return locale.languageCode == 'en' ||
                      localeLookup.languageName != sourceLocale.languageName;
                })
                .map(
                  (locale) {
                    final localeLookup = lookupAppLocalizations(locale);

                    return SelectOptionEntry(
                      value: locale,
                      label: localeLookup.languageName,
                    );
                  },
                ),
          ],
          onChanged: (value) {
            ref.read(generalSettingsProvider.notifier).setLocale(value);
          },
        );
      },
    );
  }
}

class _SendDiagnostics extends ConsumerWidget {
  const _SendDiagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final generalSettings = ref.watch(generalSettingsProvider);

    return Async(
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
    );
  }
}
