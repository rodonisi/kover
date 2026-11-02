import 'package:flutter_test/flutter_test.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/extensions/color.dart';

void main() {
  test('theme styles use the theme surface and text colors', () {
    final theme = const ThemeModel().darkTheme;
    final styles = epubThemeStylesFromTheme(theme);

    expect(
      styles.root['background-color'],
      theme.colorScheme.surface.toCssRgba(),
    );
    expect(styles.root['color'], theme.colorScheme.onSurface.toCssRgba());
    expect(
      styles.highlight['background-color'],
      theme.colorScheme.tertiaryContainer.withAlpha(0xe0).toCssRgba(),
    );
    expect(
      styles.highlight['color'],
      theme.colorScheme.onTertiaryContainer.toCssRgba(),
    );
  });
}
