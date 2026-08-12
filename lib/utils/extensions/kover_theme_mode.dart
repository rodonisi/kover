import 'package:material_ui/material_ui.dart';
import 'package:kover/riverpod/providers/theme.dart';

extension KoverThemeModeExtension on KoverThemeMode {
  ThemeMode toThemeMode() {
    return switch (this) {
      .system => ThemeMode.system,
      .light => ThemeMode.light,
      .dark || .black => ThemeMode.dark,
    };
  }
}
