import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epub_reader_settings.freezed.dart';
part 'epub_reader_settings.g.dart';

sealed class EpubReaderSettingsLimits {
  static const double fontSizeMin = 8.0;
  static const double fontSizeMax = 64.0;
  static const double fontSizeStep = 1;

  static const double marginSizeMin = LayoutConstants.smallerPadding;
  static const double marginSizeMax = LayoutConstants.largestPadding;
  static const double marginSizeStep = 4;

  static const double lineHeightMin = 0.5;
  static const double lineHeightMax = 5.0;
  static const double lineHeightStep = 0.2;

  static const double wordSpacingMin = -10.0;
  static const double wordSpacingMax = 10.0;
  static const double wordSpacingStep = 0.5;

  static const double letterSpacingMin = -10.0;
  static const double letterSpacingMax = 10.0;
  static const double letterSpacingStep = 0.5;
}

@freezed
sealed class EpubReaderSettingsState with _$EpubReaderSettingsState {
  const EpubReaderSettingsState._();
  const factory EpubReaderSettingsState({
    @Default(LayoutConstants.mediumPadding) double marginSize,
    @Default(14.0) double fontSize,
    @Default(1.5) double lineHeight,
    @Default(0.0) double wordSpacing,
    @Default(0.0) double letterSpacing,
    @Default(true) bool highlightResumePoint,
  }) = _EpubReaderSettingsState;

  factory EpubReaderSettingsState.fromJson(Map<String, Object?> json) =>
      _$EpubReaderSettingsStateFromJson(json);
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
  @override
  Future<EpubReaderSettingsState> build({required int seriesId}) async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    final defaults = await ref.watch(defaultEpubReaderSettingsProvider.future);
    return state.value ?? defaults;
  }

  Future<void> setFontSize(double newSize) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        fontSize: newSize.clamp(
          EpubReaderSettingsLimits.fontSizeMin,
          EpubReaderSettingsLimits.fontSizeMax,
        ),
      ),
    );
    log.info(
      'set font size',
      attributes: {'value': newSize, 'reader': 'epub'},
    );
  }

  Future<void> setMarginSize(double newSize) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        marginSize: newSize.clamp(
          EpubReaderSettingsLimits.marginSizeMin,
          EpubReaderSettingsLimits.marginSizeMax,
        ),
      ),
    );
    log.info(
      'set margin size',
      attributes: {'value': newSize, 'reader': 'epub'},
    );
  }

  Future<void> setLineHeight(double newSize) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        lineHeight: newSize.clamp(
          EpubReaderSettingsLimits.lineHeightMin,
          EpubReaderSettingsLimits.lineHeightMax,
        ),
      ),
    );
    log.info(
      'set line height',
      attributes: {'value': newSize, 'reader': 'epub'},
    );
  }

  Future<void> setWordSpacing(double newSize) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        wordSpacing: newSize.clamp(
          EpubReaderSettingsLimits.wordSpacingMin,
          EpubReaderSettingsLimits.wordSpacingMax,
        ),
      ),
    );
    log.info(
      'set word spacing',
      attributes: {'value': newSize, 'reader': 'epub'},
    );
  }

  Future<void> setLetterSpacing(double newSize) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        letterSpacing: newSize.clamp(
          EpubReaderSettingsLimits.letterSpacingMin,
          EpubReaderSettingsLimits.letterSpacingMax,
        ),
      ),
    );
    log.info(
      'set letter spacing',
      attributes: {
        'value': newSize,
        'reader': 'epub',
      },
    );
  }

  Future<void> setHighlightResumePoint(bool value) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(highlightResumePoint: value),
    );
    log.info(
      'set highhlight resume point',
      attributes: {'value': value, 'reader': 'epub'},
    );
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultEpubReaderSettingsProvider.future);
    state = AsyncData(defaults);
    log.info(
      'set reader settings to defaults',
      attributes: {'reader': 'epub'},
    );
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultEpubReaderSettingsProvider.notifier).setDefault(current);
    log.info(
      'set current reader settings as default',
      attributes: {'reader': 'epub'},
    );
  }
}
