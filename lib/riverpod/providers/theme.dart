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

final _lightBase = _theme.light();
final _darkBase = _theme.dark();

final _lightBorderSide = BorderSide(
  color: _lightBase.colorScheme.outline,
  width: 2.0,
);

final _darkBorderSide = BorderSide(
  color: _darkBase.colorScheme.outline,
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

final _navigationBarTheme = const NavigationBarThemeData(
  height: 64.0,
  labelBehavior: .alwaysHide,
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

  ThemeData get _lightTheme => _lightBase.copyWith(
    cardTheme: _cardTheme,
    sliderTheme: SliderThemeData(
      inactiveTrackColor: _lightBase.colorScheme.onSurface.withAlpha(0x55),
      inactiveTickMarkColor: _lightBase.colorScheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _lightBase.colorScheme.surfaceContainer.withValues(
              alpha: 0.5,
            );
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _lightBase.colorScheme.onSurface.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
    ),
    progressIndicatorTheme: _progressIndicatorTheme,
    navigationBarTheme: _navigationBarTheme,
  );

  ThemeData get _outlinedLightTheme => _lightTheme.copyWith(
    cardTheme: _outlinedLightCardTheme,
  );

  ThemeData get lightTheme => outlined ? _outlinedLightTheme : _lightTheme;

  ThemeData get _darkTheme => _darkBase.copyWith(
    cardTheme: _cardTheme,
    sliderTheme: SliderThemeData(
      inactiveTrackColor: _darkBase.colorScheme.onSurface.withAlpha(0x55),
      inactiveTickMarkColor: _darkBase.colorScheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _darkBase.colorScheme.surfaceContainer.withValues(
              alpha: 0.5,
            );
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _darkBase.colorScheme.onSurface.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
    ),
    progressIndicatorTheme: _progressIndicatorTheme,
    navigationBarTheme: _navigationBarTheme,
  );

  ThemeData get _outlinedDarkTheme => _darkTheme.copyWith(
    cardTheme: _outlinedDarkCardTheme,
  );

  ThemeData get darkTheme => outlined ? _outlinedDarkTheme : _darkTheme;

  ThemeData get theme {
    return switch (mode) {
      .light => lightTheme,
      .dark => darkTheme,
      .system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness == .dark
            ? darkTheme
            : lightTheme,
    };
  }
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
