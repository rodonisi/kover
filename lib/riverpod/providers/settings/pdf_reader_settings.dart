import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pdf_reader_settings.freezed.dart';
part 'pdf_reader_settings.g.dart';

sealed class PdfReaderSettingsLimits {
  /// Crop values are percentages of the page trimmed from each side.
  static const double cropMin = 0;
  static const double cropMax = 25;
  static const double cropStep = 1;
}

enum PdfReaderMode {
  horizontal,
  vertical,
}

@freezed
sealed class PdfReaderSettingsState with _$PdfReaderSettingsState {
  const PdfReaderSettingsState._();
  const factory PdfReaderSettingsState({
    @Default(PdfReaderMode.vertical) PdfReaderMode readerMode,
    @Default(true) bool ignoreSafeAreas,
    @Default(false) bool lockHorizontalPan,
    @Default(0) double horizontalCrop,
    @Default(0) double verticalCrop,
  }) = _PdfReaderSettingsState;

  factory PdfReaderSettingsState.fromJson(Map<String, Object?> json) =>
      _$PdfReaderSettingsStateFromJson(json);
}

extension on PdfReaderSettingsState {
  PdfReaderSettingsState clampLimits() => copyWith(
    horizontalCrop: _clampCrop(horizontalCrop),
    verticalCrop: _clampCrop(verticalCrop),
  );
}

double _clampCrop(double value) => value.clamp(
  PdfReaderSettingsLimits.cropMin,
  PdfReaderSettingsLimits.cropMax,
);

@riverpod
@JsonPersist()
class DefaultPdfReaderSettings extends _$DefaultPdfReaderSettings {
  @override
  Future<PdfReaderSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value?.clampLimits() ?? const PdfReaderSettingsState();
  }

  void setDefault(PdfReaderSettingsState newDefault) {
    state = AsyncData(newDefault);
  }
}

@riverpod
@JsonPersist()
class PdfReaderSettings extends _$PdfReaderSettings {
  @override
  Future<PdfReaderSettingsState> build({required int seriesId}) async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    final defaults = await ref.watch(defaultPdfReaderSettingsProvider.future);
    return state.value?.clampLimits() ?? defaults;
  }

  Future<void> setHorizontalCrop(double value) async {
    final current = await future;

    state = AsyncData(current.copyWith(horizontalCrop: _clampCrop(value)));
    log.info(
      'set horizontal crop',
      attributes: {'value': value, 'reader': 'pdf'},
    );
  }

  Future<void> setVerticalCrop(double value) async {
    final current = await future;

    state = AsyncData(current.copyWith(verticalCrop: _clampCrop(value)));
    log.info(
      'set vertical crop',
      attributes: {'value': value, 'reader': 'pdf'},
    );
  }

  Future<void> setReaderMode(PdfReaderMode newMode) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(readerMode: newMode),
    );
    log.info(
      'set reader mode',
      attributes: {
        'value': newMode,
        'reader': 'pdf',
      },
    );
  }

  Future<void> setLockHorizontalPan(bool value) async {
    final current = await future;

    state = AsyncData(current.copyWith(lockHorizontalPan: value));
    log.info(
      'set lock horizontal pan',
      attributes: {'value': value, 'reader': 'pdf'},
    );
  }

  Future<void> setIgnoreSafeAreas(bool ignore) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(ignoreSafeAreas: ignore),
    );
    log.info(
      'set ignore safe areas',
      attributes: {
        'value': ignore,
        'reader': 'pdf',
      },
    );
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultPdfReaderSettingsProvider.future);
    state = AsyncData(defaults);
    log.info(
      'reset reader to default settings',
      attributes: {'reader': 'pdf'},
    );
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultPdfReaderSettingsProvider.notifier).setDefault(current);
    log.info(
      'set current settings as default',
      attributes: {'reader': 'pdf'},
    );
  }
}
