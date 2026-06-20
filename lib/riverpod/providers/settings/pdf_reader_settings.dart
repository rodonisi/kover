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

@freezed
sealed class PdfReaderSettingsState with _$PdfReaderSettingsState {
  const PdfReaderSettingsState._();
  const factory PdfReaderSettingsState({
    @Default(PdfReaderMode.vertical) PdfReaderMode readerMode,
    @Default(true) bool ignoreSafeAreas,
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
        'value': .string(newMode.toString()),
        'reader': const .string('pdf'),
      },
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
        'value': .bool(ignore),
        'reader': const .string('pdf'),
      },
    );
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultPdfReaderSettingsProvider.future);
    state = AsyncData(defaults);
    log.info(
      'reset reader to default settings',
      attributes: {'reader': const .string('pdf')},
    );
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultPdfReaderSettingsProvider.notifier).setDefault(current);
    log.info(
      'set current settings as default',
      attributes: {'reader': const .string('pdf')},
    );
  }
}
