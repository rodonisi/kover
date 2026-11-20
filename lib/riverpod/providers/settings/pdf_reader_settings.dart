import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pdf_reader_settings.freezed.dart';
part 'pdf_reader_settings.g.dart';

enum PdfReaderMode {
  horizontal,
  vertical,
}

sealed class PdfReaderSettingsLimits {
  /// Multiplier of the viewer's fit zoom.
  static const double defaultZoomMin = 1.0;
  static const double defaultZoomMax = 2.0;
  static const double defaultZoomStep = 0.05;
}

@freezed
sealed class PdfReaderSettingsState with _$PdfReaderSettingsState {
  const PdfReaderSettingsState._();
  const factory PdfReaderSettingsState({
    @Default(PdfReaderMode.vertical) PdfReaderMode readerMode,
    @Default(true) bool ignoreSafeAreas,
    @Default(false) bool lockHorizontalPan,
    @Default(1.0) double defaultZoom,
  }) = _PdfReaderSettingsState;

  factory PdfReaderSettingsState.fromJson(Map<String, Object?> json) =>
      _$PdfReaderSettingsStateFromJson(json);
}

@riverpod
@JsonPersist()
class DefaultPdfReaderSettings extends _$DefaultPdfReaderSettings {
  @override
  Future<PdfReaderSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const PdfReaderSettingsState();
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
    return state.value ?? defaults;
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

  Future<void> setDefaultZoom(double zoom) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        defaultZoom: zoom.clamp(
          PdfReaderSettingsLimits.defaultZoomMin,
          PdfReaderSettingsLimits.defaultZoomMax,
        ),
      ),
    );
    log.info(
      'set default zoom',
      attributes: {'value': zoom, 'reader': 'pdf'},
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
