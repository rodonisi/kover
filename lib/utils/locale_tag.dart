import 'dart:ui';

import 'package:intl/locale.dart' as intl;

/// Parses a locale tag into a [Locale].
/// Returns null when the tag is not a valid Unicode locale identifier.
Locale? parseLocale(String tag) {
  final parsed = intl.Locale.tryParse(tag);
  if (parsed == null) {
    return null;
  }

  return Locale.fromSubtags(
    languageCode: parsed.languageCode,
    scriptCode: parsed.scriptCode,
    countryCode: parsed.countryCode,
  );
}
