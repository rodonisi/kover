import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff004e49),
      surfaceTint: Color(0xff056a64),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff006862),
      onPrimaryContainer: Color(0xff94e4dc),
      secondary: Color(0xff476460),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffc7e6e2),
      onSecondaryContainer: Color(0xff4b6865),
      tertiary: Color(0xff445e79),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff5c7793),
      onTertiaryContainer: Color(0xfffdfcff),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff7faf8),
      onSurface: Color(0xff181c1c),
      onSurfaceVariant: Color(0xff3e4947),
      outline: Color(0xff6e7977),
      outlineVariant: Color(0xffbec9c7),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3130),
      inversePrimary: Color(0xff85d4cd),
      primaryFixed: Color(0xffa1f1e9),
      onPrimaryFixed: Color(0xff00201e),
      primaryFixedDim: Color(0xff85d4cd),
      onPrimaryFixedVariant: Color(0xff00504b),
      secondaryFixed: Color(0xffcae9e4),
      onSecondaryFixed: Color(0xff02201e),
      secondaryFixedDim: Color(0xffaecdc9),
      onSecondaryFixedVariant: Color(0xff304c49),
      tertiaryFixed: Color(0xffcfe5ff),
      onTertiaryFixed: Color(0xff001d33),
      tertiaryFixedDim: Color(0xffaec9e8),
      onTertiaryFixedVariant: Color(0xff2e4963),
      surfaceDim: Color(0xffd7dbd9),
      surfaceBright: Color(0xfff7faf8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff1f4f3),
      surfaceContainer: Color(0xffebefed),
      surfaceContainerHigh: Color(0xffe6e9e7),
      surfaceContainerHighest: Color(0xffe0e3e2),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003e3a),
      surfaceTint: Color(0xff056a64),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff006862),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1f3b38),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff56726f),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff1c3851),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff556f8b),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff7faf8),
      onSurface: Color(0xff0e1211),
      onSurfaceVariant: Color(0xff2e3837),
      outline: Color(0xff4a5553),
      outlineVariant: Color(0xff646f6d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3130),
      inversePrimary: Color(0xff85d4cd),
      primaryFixed: Color(0xff227973),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff005f5a),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff56726f),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff3e5a57),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff556f8b),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff3c5772),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc4c7c6),
      surfaceBright: Color(0xfff7faf8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff1f4f3),
      surfaceContainer: Color(0xffe6e9e7),
      surfaceContainerHigh: Color(0xffdadddc),
      surfaceContainerHighest: Color(0xffcfd2d1),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff00322f),
      surfaceTint: Color(0xff056a64),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff00534e),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff14312e),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff324e4b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff102e47),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff304b65),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff7faf8),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff242e2d),
      outlineVariant: Color(0xff414b4a),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3130),
      inversePrimary: Color(0xff85d4cd),
      primaryFixed: Color(0xff00534e),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff003a36),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff324e4b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff1b3735),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff304b65),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff18354d),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb6b9b8),
      surfaceBright: Color(0xfff7faf8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeef1f0),
      surfaceContainer: Color(0xffe0e3e2),
      surfaceContainerHigh: Color(0xffd2d5d4),
      surfaceContainerHighest: Color(0xffc4c7c6),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff85d4cd),
      surfaceTint: Color(0xff85d4cd),
      onPrimary: Color(0xff003734),
      primaryContainer: Color(0xff006862),
      onPrimaryContainer: Color(0xff94e4dc),
      secondary: Color(0xffaecdc9),
      onSecondary: Color(0xff193532),
      secondaryContainer: Color(0xff324e4b),
      onSecondaryContainer: Color(0xffa0beba),
      tertiary: Color(0xffaec9e8),
      onTertiary: Color(0xff16324b),
      tertiaryContainer: Color(0xff7893b0),
      onTertiaryContainer: Color(0xff0d2b44),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff101414),
      onSurface: Color(0xffe0e3e2),
      onSurfaceVariant: Color(0xffbec9c7),
      outline: Color(0xff889391),
      outlineVariant: Color(0xff3e4947),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe0e3e2),
      inversePrimary: Color(0xff056a64),
      primaryFixed: Color(0xffa1f1e9),
      onPrimaryFixed: Color(0xff00201e),
      primaryFixedDim: Color(0xff85d4cd),
      onPrimaryFixedVariant: Color(0xff00504b),
      secondaryFixed: Color(0xffcae9e4),
      onSecondaryFixed: Color(0xff02201e),
      secondaryFixedDim: Color(0xffaecdc9),
      onSecondaryFixedVariant: Color(0xff304c49),
      tertiaryFixed: Color(0xffcfe5ff),
      onTertiaryFixed: Color(0xff001d33),
      tertiaryFixedDim: Color(0xffaec9e8),
      onTertiaryFixedVariant: Color(0xff2e4963),
      surfaceDim: Color(0xff101414),
      surfaceBright: Color(0xff363a39),
      surfaceContainerLowest: Color(0xff0b0f0e),
      surfaceContainerLow: Color(0xff181c1c),
      surfaceContainer: Color(0xff1c2020),
      surfaceContainerHigh: Color(0xff272b2a),
      surfaceContainerHighest: Color(0xff313635),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff9bebe3),
      surfaceTint: Color(0xff85d4cd),
      onPrimary: Color(0xff002b28),
      primaryContainer: Color(0xff4d9e97),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffc4e3de),
      onSecondary: Color(0xff0d2a28),
      secondaryContainer: Color(0xff799693),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffc3dfff),
      onTertiary: Color(0xff072740),
      tertiaryContainer: Color(0xff7893b0),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff101414),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd4dfdc),
      outline: Color(0xffa9b4b2),
      outlineVariant: Color(0xff889391),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe0e3e2),
      inversePrimary: Color(0xff00514c),
      primaryFixed: Color(0xffa1f1e9),
      onPrimaryFixed: Color(0xff001413),
      primaryFixedDim: Color(0xff85d4cd),
      onPrimaryFixedVariant: Color(0xff003e3a),
      secondaryFixed: Color(0xffcae9e4),
      onSecondaryFixed: Color(0xff001413),
      secondaryFixedDim: Color(0xffaecdc9),
      onSecondaryFixedVariant: Color(0xff1f3b38),
      tertiaryFixed: Color(0xffcfe5ff),
      onTertiaryFixed: Color(0xff001223),
      tertiaryFixedDim: Color(0xffaec9e8),
      onTertiaryFixedVariant: Color(0xff1c3851),
      surfaceDim: Color(0xff101414),
      surfaceBright: Color(0xff414544),
      surfaceContainerLowest: Color(0xff050808),
      surfaceContainerLow: Color(0xff1a1e1e),
      surfaceContainer: Color(0xff252928),
      surfaceContainerHigh: Color(0xff2f3333),
      surfaceContainerHighest: Color(0xff3a3e3e),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffaefff6),
      surfaceTint: Color(0xff85d4cd),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff81d1c9),
      onPrimaryContainer: Color(0xff000e0c),
      secondary: Color(0xffd7f6f2),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffaac9c5),
      onSecondaryContainer: Color(0xff000e0c),
      tertiary: Color(0xffe7f1ff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffaac5e4),
      onTertiaryContainer: Color(0xff000c1a),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff101414),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffe7f2f0),
      outlineVariant: Color(0xffbac5c3),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe0e3e2),
      inversePrimary: Color(0xff00514c),
      primaryFixed: Color(0xffa1f1e9),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff85d4cd),
      onPrimaryFixedVariant: Color(0xff001413),
      secondaryFixed: Color(0xffcae9e4),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffaecdc9),
      onSecondaryFixedVariant: Color(0xff001413),
      tertiaryFixed: Color(0xffcfe5ff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffaec9e8),
      onTertiaryFixedVariant: Color(0xff001223),
      surfaceDim: Color(0xff101414),
      surfaceBright: Color(0xff4d5150),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1c2020),
      surfaceContainer: Color(0xff2d3130),
      surfaceContainerHigh: Color(0xff383c3b),
      surfaceContainerHighest: Color(0xff434847),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
