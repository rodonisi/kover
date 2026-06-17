import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_dim_settings.freezed.dart';
part 'reader_dim_settings.g.dart';

sealed class ReaderDimSettingsLimits {
  static const double dimMin = 0.0;
  static const double dimMax = 0.9;
  static const double dimStep = 5.0;
}

@freezed
sealed class ReaderDimSettingsState with _$ReaderDimSettingsState {
  const ReaderDimSettingsState._();
  const factory ReaderDimSettingsState({
    @Default(0.0) double dimLevel,
  }) = _ReaderDimSettingsState;

  factory ReaderDimSettingsState.fromJson(Map<String, Object?> json) =>
      _$ReaderDimSettingsStateFromJson(json);
}

@riverpod
@JsonPersist()
class ReaderDimSettings extends _$ReaderDimSettings {
  @override
  Future<ReaderDimSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const ReaderDimSettingsState();
  }

  Future<void> adjustDimLevel(double delta) async {
    final current = await future;
    state = AsyncData(
      current.copyWith(
        dimLevel: (current.dimLevel + delta).clamp(
          ReaderDimSettingsLimits.dimMin,
          ReaderDimSettingsLimits.dimMax,
        ),
      ),
    );
    log.info(
      'adjust dim level',
      attributes: {'value': .double(state.value!.dimLevel)},
    );
  }

  Future<void> setDimLevel(double level) async {
    final current = await future;
    state = AsyncData(
      current.copyWith(
        dimLevel: level.clamp(
          ReaderDimSettingsLimits.dimMin,
          ReaderDimSettingsLimits.dimMax,
        ),
      ),
    );
    log.info(
      'set dim level',
      attributes: {'value': .double(level)},
    );
  }
}
