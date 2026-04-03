import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_settings.freezed.dart';
part 'download_settings.g.dart';

@freezed
sealed class DownloadSettingsState with _$DownloadSettingsState {
  const factory DownloadSettingsState({
    @Default(3) int concurrentDownloads,
  }) = _DownloadSettingsState;

  factory DownloadSettingsState.fromJson(Map<String, Object?> json) =>
      _$DownloadSettingsStateFromJson(json);
}

@Riverpod(keepAlive: true)
@JsonPersist()
class DownloadSettings extends _$DownloadSettings {
  @override
  Future<DownloadSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const DownloadSettingsState();
  }

  Future<void> setConcurrentDownloads(int count) async {
    final current = await future;
    state = AsyncData(current.copyWith(concurrentDownloads: count));
  }
}
