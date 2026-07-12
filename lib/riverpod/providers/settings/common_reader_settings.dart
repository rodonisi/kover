import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'common_reader_settings.freezed.dart';
part 'common_reader_settings.g.dart';

enum OrientationLock { none, portrait, landscape }

@freezed
sealed class CommonReaderSettingsState with _$CommonReaderSettingsState {
  const factory CommonReaderSettingsState({
    @Default(ReadDirection.leftToRight) ReadDirection readDirection,
    @Default(OrientationLock.none) OrientationLock orientationLock,
    @Default(true) bool showProgressBar,
    @Default(true) bool navigationGersturesEnabled,
  }) = _CommonReaderSettingsState;

  factory CommonReaderSettingsState.fromJson(Map<String, dynamic> json) =>
      _$CommonReaderSettingsStateFromJson(json);
}

@riverpod
@JsonPersist()
class DefaultCommonReaderSettings extends _$DefaultCommonReaderSettings {
  @override
  Future<CommonReaderSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const CommonReaderSettingsState();
  }

  void setDefault(CommonReaderSettingsState newDefault) {
    state = AsyncData(newDefault);
  }
}

@riverpod
@JsonPersist()
class CommonReaderSettings extends _$CommonReaderSettings {
  @override
  Future<CommonReaderSettingsState> build({required int seriesId}) async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    final defaults = await ref.watch(
      defaultCommonReaderSettingsProvider.future,
    );
    return state.value ?? defaults;
  }

  Future<void> setReadDirection(ReadDirection direction) async {
    final current = await future;

    state = AsyncData(current.copyWith(readDirection: direction));
    log.info(
      'toggle read direction',
      attributes: {
        'value': .string(direction.name),
        'series_format': .string(await _seriesFormat()),
      },
    );
  }

  Future<void> setShowProgressBar(bool value) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(showProgressBar: value),
    );

    log.info(
      'set show progress bar',
      attributes: {
        'value': .bool(value),
        'series_format': .string(await _seriesFormat()),
      },
    );
  }

  Future<void> setOrientationLock(OrientationLock newLock) async {
    final current = await future;
    state = AsyncData(
      current.copyWith(orientationLock: newLock),
    );

    log.info(
      'set orientation lock',
      attributes: {
        'value': .string(newLock.name),
        'series_format': .string(await _seriesFormat()),
      },
    );
  }

  Future<void> setNavigationGesturesEnabled(bool value) async {
    final current = await future;
    state = AsyncData(
      current.copyWith(navigationGersturesEnabled: value),
    );

    log.info(
      'set navigation gestures enabled',
      attributes: {
        'value': .bool(value),
        'series_format': .string(await _seriesFormat()),
      },
    );
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultCommonReaderSettingsProvider.future);
    state = AsyncData(defaults);

    log.info(
      'set common settings to defaults',
      attributes: {
        'series_format': .string(await _seriesFormat()),
      },
    );
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultCommonReaderSettingsProvider.notifier).setDefault(current);

    log.info(
      'set current reader settings as default',
      attributes: {'series_format': .string(await _seriesFormat())},
    );
  }

  Future<String> _seriesFormat() async {
    final series = await ref.read(
      seriesProvider(
        seriesId: seriesId,
      ).future,
    );
    return series.format.name;
  }
}
