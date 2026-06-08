import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

@freezed
sealed class GeneralSettingsState with _$GeneralSettingsState {
  const factory GeneralSettingsState({
    @Default(false) bool sendDiagnostics,
  }) = _GeneralSettingsState;

  factory GeneralSettingsState.fromJson(Map<String, Object?> json) =>
      _$GeneralSettingsStateFromJson(json);
}

@riverpod
@JsonPersist()
class GeneralSettings extends _$GeneralSettings {
  @override
  Future<GeneralSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const GeneralSettingsState();
  }

  Future<void> setSendDiagnostics(bool value) async {
    final current = await future;
    log.i('set sendDiagnostics to $value');
    state = AsyncData(current.copyWith(sendDiagnostics: value));
  }
}
