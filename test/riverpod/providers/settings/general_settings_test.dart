import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';

void main() {
  Locale? localeOrNull(String tag) =>
      GeneralSettingsState(localeString: tag).locale;

  Locale localeOf(String tag) => localeOrNull(tag)!;

  group('GeneralSettingsState.locale', () {
    test('returns null when unset or unparseable', () {
      expect(const GeneralSettingsState().locale, isNull);
      expect(localeOrNull('not a locale'), isNull);
    });

    test('parses a language-only tag', () {
      expect(localeOf('it'), equals(const Locale('it')));
    });

    test('parses a country tag', () {
      expect(localeOf('pt_BR'), equals(const Locale('pt', 'BR')));
      expect(localeOf('pt-BR'), equals(const Locale('pt', 'BR')));
    });

    test('parses a script tag', () {
      expect(
        localeOf('zh_Hant_TW'),
        equals(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ),
      );
    });

    test('falls back to the language for an unsupported region', () {
      expect(
        basicLocaleListResolution(
          <Locale>[localeOf('en_GB')],
          AppLocalizations.supportedLocales,
        ),
        equals(const Locale('en')),
      );
    });
  });
}
