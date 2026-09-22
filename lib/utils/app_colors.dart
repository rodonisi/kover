import 'package:material_ui/material_ui.dart';

/// Additional semantic colors that are not part of the Material [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const light = AppColors(
    warning: Color(0xff7a5900),
    onWarning: Color(0xffffffff),
    warningContainer: Color(0xffffdea1),
    onWarningContainer: Color(0xff261a00),
  );

  static const dark = AppColors(
    warning: Color(0xfff2bf48),
    onWarning: Color(0xff412d00),
    warningContainer: Color(0xff5e4200),
    onWarningContainer: Color(0xffffdea8),
  );

  @override
  AppColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}
