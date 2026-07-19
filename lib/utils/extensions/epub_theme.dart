import 'package:flutter/material.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/theme.dart';

extension EpubThemeExtension on EpubTheme {
  ThemeData? get data {
    return switch (this) {
      .matchTheme => null,
      .light => const ThemeModel().lightTheme,
      .sepia => const ThemeModel().sepiaTheme,
      .dark => const ThemeModel().darkTheme,
    };
  }
}
