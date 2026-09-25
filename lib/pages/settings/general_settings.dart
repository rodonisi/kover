import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/settings/navbar_editor.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/locale_tag.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/navigate_option.dart';
import 'package:kover/widgets/settings/select_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class GeneralSettings extends ConsumerWidget {
  const GeneralSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Card(
      margin: .zero,
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
            const _DirectionalityOverride(),
            const NavbarEditor(),
            const _SendDiagnostics(),
            const _LocalLogs(),
          ],
        ),
      ),
    );
  }
}

class _Locale extends ConsumerWidget {
  const _Locale();

  static Locale get _systemLocale {
    final system = parseLocale(Intl.systemLocale);

    return system != null && AppLocalizations.delegate.isSupported(system)
        ? system
        : AppLocalizations.supportedLocales.first;
  }

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
              label: lookupAppLocalizations(_systemLocale).system,
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

class _DirectionalityOverride extends ConsumerWidget {
  const _DirectionalityOverride();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final generalSettings = ref.watch(
      generalSettingsProvider.select(
        (state) => state.whenData((data) => data.textDirection),
      ),
    );

    return Async(
      asyncValue: generalSettings,
      data: (textDirection) => SelectOption<TextDirection?>(
        title: l.directionality,
        description: l.directionalityDescription,
        value: textDirection,
        options: [
          SelectOptionEntry(
            value: null,
            label: l.localeDefault,
            icon: KoverIcons.directionality,
          ),
          SelectOptionEntry(
            value: .ltr,
            label: l.leftToRight,
            icon: KoverIcons.ltr,
          ),
          SelectOptionEntry(
            value: .rtl,
            label: l.rightToLeft,
            icon: KoverIcons.rtl,
          ),
        ],
        onChanged: (value) {
          ref.read(generalSettingsProvider.notifier).setTextDirection(value);
        },
      ),
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

class _LocalLogs extends StatelessWidget {
  const _LocalLogs();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return NavigateOption(
      title: l.logs,
      leadingIcon: KoverIcons.logs,
      onTap: () {
        const LocalLogsRoute().push(context);
      },
    );
  }
}
