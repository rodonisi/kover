import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/log_entry.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';

part 'local_log.freezed.dart';
part 'local_log.g.dart';

@freezed
sealed class LocalLogModel with _$LocalLogModel {
  const LocalLogModel._();

  const factory LocalLogModel({
    @Default([]) List<LogEntry> entries,
  }) = _LocalLogModel;

  factory LocalLogModel.fromJson(Map<String, dynamic> json) =>
      _$LocalLogModelFromJson(json);
}

@riverpod
@JsonPersist()
class LocalLog extends _$LocalLog {
  static const maxEntries = 500;

  @override
  Future<LocalLogModel> build() async {
    await persist(
      ref.watch(storageProvider.future),
    ).future;

    log.sink = _addEntry;
    ref.onDispose(() {
      log.sink = null;
    });

    return state.value ?? const LocalLogModel();
  }

  Future<void> _addEntry(LogEntry entry) async {
    final currentEntries = (await future).entries;
    final updatedEntries = [...currentEntries, entry];

    if (updatedEntries.length > maxEntries) {
      updatedEntries.removeRange(0, updatedEntries.length - maxEntries);
    }

    state = AsyncData(LocalLogModel(entries: updatedEntries));
  }
}
