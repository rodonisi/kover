import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/theme.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/experimental/persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme.freezed.dart';
part 'theme.g.dart';

final CardThemeData cardThemeData = const CardThemeData();

final _theme = MaterialTheme(
  Typography.material2021().black,
);

final _lightBorderSide = BorderSide(
  color: _theme.light().colorScheme.outline,
  width: 2.0,
);

final _darkBorderSide = BorderSide(
  color: _theme.light().colorScheme.outline,
  width: 2.0,
);

final _cardTheme = const CardThemeData(elevation: 0);
final _outlinedLightCardTheme = _cardTheme.copyWith(
  shape: RoundedRectangleBorder(
    side: _lightBorderSide,
    borderRadius: BorderRadius.circular(12.0),
  ),
);

final _outlinedDarkCardTheme = _cardTheme.copyWith(
  shape: RoundedRectangleBorder(
    side: _darkBorderSide,
    borderRadius: BorderRadius.circular(12.0),
  ),
);

final _progressIndicatorTheme = const ProgressIndicatorThemeData(
  strokeCap: .round,
);

@freezed
sealed class ThemeModel with _$ThemeModel {
  const ThemeModel._();
  const factory ThemeModel({
    @Default(ThemeMode.system) ThemeMode mode,
    @Default(false) bool outlined,
  }) = _ThemeModel;

  factory ThemeModel.fromJson(Map<String, Object?> json) =>
      _$ThemeModelFromJson(json);

  ThemeData get _lightTheme => _theme.light().copyWith(
    cardTheme: _cardTheme,
    sliderTheme: SliderThemeData(
      inactiveTrackColor: _theme.light().colorScheme.onSurface.withAlpha(0x55),
      inactiveTickMarkColor: _theme.light().colorScheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _theme.light().colorScheme.surfaceContainer.withValues(
              alpha: 0.5,
            );
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _theme.light().colorScheme.onSurface.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
    ),
    progressIndicatorTheme: _progressIndicatorTheme,
  );

  ThemeData get _outlinedLightTheme => _lightTheme.copyWith(
    cardTheme: _outlinedLightCardTheme,
  );

  ThemeData get lightTheme => outlined ? _outlinedLightTheme : _lightTheme;

  ThemeData get _darkTheme => _theme.dark().copyWith(
    cardTheme: _cardTheme,
    sliderTheme: SliderThemeData(
      inactiveTrackColor: _theme.dark().colorScheme.onSurface.withAlpha(0x55),
      inactiveTickMarkColor: _theme.dark().colorScheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _theme.dark().colorScheme.surfaceContainer.withValues(
              alpha: 0.5,
            );
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _theme.dark().colorScheme.onSurface.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
    ),
    progressIndicatorTheme: _progressIndicatorTheme,
  );

  ThemeData get _outlinedDarkTheme => _darkTheme.copyWith(
    cardTheme: _outlinedDarkCardTheme,
  );

  ThemeData get darkTheme => outlined ? _outlinedDarkTheme : _darkTheme;
}

@riverpod
@JsonPersist()
class Theme extends _$Theme {
  @override
  Future<ThemeModel> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const ThemeModel();
  }

  Future<void> setMode(ThemeMode mode) async {
    final current = await future;

    state = AsyncData(current.copyWith(mode: mode));
  }

  Future<void> setOutlined(bool value) async {
    final current = await future;

    state = AsyncData(current.copyWith(outlined: value));
  }

  void reset() {
    state = const AsyncData(ThemeModel());
  }
}
