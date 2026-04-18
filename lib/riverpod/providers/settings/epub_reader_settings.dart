import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader_settings.freezed.dart';
part 'epub_reader_settings.g.dart';

@freezed
sealed class EpubReaderSettingsState with _$EpubReaderSettingsState {
  const EpubReaderSettingsState._();
  const factory EpubReaderSettingsState({
    @Default(LayoutConstants.mediumPadding) double marginSize,
    @Default(14.0) double fontSize,
    @Default(1.5) double lineHeight,
    @Default(ReadDirection.leftToRight) ReadDirection readDirection,
    @Default(true) bool highlightResumePoint,
  }) = _EpubReaderSettingsState;

  factory EpubReaderSettingsState.fromJson(Map<String, Object?> json) =>
      _$EpubReaderSettingsStateFromJson(json);

  static const double minFontSize = 8.0;
  static const double maxFontSize = 24.0;
  static const double minMarginSize = LayoutConstants.smallerPadding;
  static const double maxMarginSize = LayoutConstants.largerPadding;
  static const double minLineHeight = 0.5;
  static const double maxLineHeight = 3.0;

  bool get canIncreaseFontSize => fontSize < maxFontSize;
  bool get canDecreaseFontSize => fontSize > minFontSize;
  bool get canIncreaseMarginSize => marginSize < maxMarginSize;
  bool get canDecreaseMarginSize => marginSize > minMarginSize;
  bool get canIncreaseLineHeight => lineHeight < maxLineHeight;
  bool get canDecreaseLineHeight => lineHeight > minLineHeight;
}

@riverpod
@JsonPersist()
class DefaultEpubReaderSettings extends _$DefaultEpubReaderSettings {
  @override
  Future<EpubReaderSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const EpubReaderSettingsState();
  }

  void setDefault(EpubReaderSettingsState newDefault) {
    state = AsyncData(newDefault);
  }
}

@riverpod
@JsonPersist()
class EpubReaderSettings extends _$EpubReaderSettings {
  static const _fontSizeStep = 1;
  static const _marginSizeStep = 4;
  static const _lineHeightStep = 0.2;

  @override
  Future<EpubReaderSettingsState> build({required int seriesId}) async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    final defaults = await ref.watch(defaultEpubReaderSettingsProvider.future);
    return state.value ?? defaults;
  }

  Future<void> toggleReadDirection() async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        readDirection: current.readDirection == ReadDirection.leftToRight
            ? ReadDirection.rightToLeft
            : ReadDirection.leftToRight,
      ),
    );
  }

  Future<void> increaseFontSize() async {
    final current = await future;

    if (current.fontSize >= EpubReaderSettingsState.maxFontSize) {
      return;
    }
    state = AsyncData(
      current.copyWith(fontSize: current.fontSize + _fontSizeStep),
    );
  }

  Future<void> decreaseFontSize() async {
    final current = await future;

    if (current.fontSize <= EpubReaderSettingsState.minFontSize) {
      return;
    }

    state = AsyncData(
      current.copyWith(fontSize: current.fontSize - _fontSizeStep),
    );
  }

  Future<void> increaseMarginSize() async {
    final current = await future;

    if (current.marginSize >= EpubReaderSettingsState.maxMarginSize) {
      return;
    }

    state = AsyncData(
      current.copyWith(marginSize: current.marginSize + _marginSizeStep),
    );
  }

  Future<void> decreaseMarginSize() async {
    final current = await future;

    if (current.marginSize <= EpubReaderSettingsState.minMarginSize) {
      return;
    }

    state = AsyncData(
      current.copyWith(marginSize: current.marginSize - _marginSizeStep),
    );
  }

  Future<void> increaseLineHeight() async {
    final current = await future;

    if (current.lineHeight >= EpubReaderSettingsState.maxLineHeight) {
      return;
    }

    state = AsyncData(
      current.copyWith(lineHeight: current.lineHeight + _lineHeightStep),
    );
  }

  Future<void> decreaseLineHeight() async {
    final current = await future;

    if (current.lineHeight <= EpubReaderSettingsState.minLineHeight) {
      return;
    }

    state = AsyncData(
      current.copyWith(lineHeight: current.lineHeight - _lineHeightStep),
    );
  }

  Future<void> setHighlightResumePoint(bool value) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(highlightResumePoint: value),
    );
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultEpubReaderSettingsProvider.future);
    state = AsyncData(defaults);
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultEpubReaderSettingsProvider.notifier).setDefault(current);
  }
}
