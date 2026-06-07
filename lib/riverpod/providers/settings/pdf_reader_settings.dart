import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/models/read_direction.dart';
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
    @Default(ReadDirection.leftToRight) ReadDirection readDirection,
    @Default(PdfReaderMode.vertical) PdfReaderMode readerMode,
    @Default(true) bool ignoreSafeAreas,
    @Default(true) bool showProgressBar,
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

  Future<void> setReadDirection(ReadDirection newDirection) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(readDirection: newDirection),
    );
    log.i('set readDirection to $newDirection');
  }

  Future<void> setReaderMode(PdfReaderMode newMode) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(readerMode: newMode),
    );
    log.i('set readerMode to $newMode');
  }

  Future<void> setIgnoreSafeAreas(bool ignore) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(ignoreSafeAreas: ignore),
    );
    log.i('set ignoreSafeAreas to $ignore');
  }

  Future<void> setShowProgressBar(bool show) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(showProgressBar: show),
    );
    log.i('set showProgressBar to $show');
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultPdfReaderSettingsProvider.future);
    state = AsyncData(defaults);
    log.i('reset to default settings');
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultPdfReaderSettingsProvider.notifier).setDefault(current);
    log.i('set current settings as default');
  }
}
