import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'oneoffs.freezed.dart';
part 'oneoffs.g.dart';

@freezed
sealed class OneOffsState with _$OneOffsState {
  const OneOffsState._();

  const factory OneOffsState({
    @Default(false) bool monitoringOptOutPopupShown,
  }) = _OneOffsState;

  factory OneOffsState.fromJson(Map<String, Object?> json) =>
      _$OneOffsStateFromJson(json);
}

@riverpod
@JsonPersist()
class OneOffs extends _$OneOffs {
  @override
  Future<OneOffsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const OneOffsState();
  }

  Future<void> setMonitoringOptOutPopupShown() async {
    final current = await future;
    state = AsyncData(current.copyWith(monitoringOptOutPopupShown: true));
  }
}
