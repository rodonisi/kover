import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:path/path.dart' as p;
import 'package:kover/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.freezed.dart';
part 'database.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
}

@riverpod
Future<int> databaseSize(Ref ref) async {
  ref.listen(clearOperationProvider, (_, _) => ref.invalidateSelf());
  ref.listen(syncManagerProvider, (_, _) => ref.invalidateSelf());
  ref.listen(downloadManagerProvider, (_, _) => ref.invalidateSelf());

  final applicationSubbportDir = await getApplicationSupportDirectory();
  final dbFile = File(
    p.join(applicationSubbportDir.path, '${AppDatabase.dbName}.sqlite'),
  );
  if (await dbFile.exists()) {
    final bytes = await dbFile.length();
    return bytes;
  } else {
    return 0;
  }
}

@riverpod
class ClearDatabase extends _$ClearDatabase {
  @override
  Future<ClearOperationStatus> build() async {
    final state = await ref.watch(clearOperationProvider.future);

    if (state.type == .clearDatabase) {
      return state.status;
    }

    if (state.status != .idle) {
      return .busy;
    }

    return .idle;
  }

  Future<void> clearDatabase() async {
    await ref
        .read(clearOperationProvider.notifier)
        .performOperation(
          type: .clearDatabase,
          operation: () async {
            await ref.read(databaseProvider).clearDb();
          },
        );
  }
}

@riverpod
class ClearDownloads extends _$ClearDownloads {
  @override
  Future<ClearOperationStatus> build() async {
    final state = await ref.watch(clearOperationProvider.future);

    if (state.type == .clearDownloads) {
      return state.status;
    }

    if (state.status != .idle) {
      return .busy;
    }

    return .idle;
  }

  Future<void> clearDownloads() async {
    await ref
        .read(clearOperationProvider.notifier)
        .performOperation(
          type: .clearDownloads,
          operation: () async {
            await ref.read(databaseProvider).clearDownloads();
          },
        );
  }
}

@riverpod
class ClearCovers extends _$ClearCovers {
  @override
  Future<ClearOperationStatus> build() async {
    final state = await ref.watch(clearOperationProvider.future);

    if (state.type == .clearCovers) {
      return state.status;
    }

    if (state.status != .idle) {
      return .busy;
    }

    return .idle;
  }

  Future<void> clearCovers() async {
    await ref
        .read(clearOperationProvider.notifier)
        .performOperation(
          type: .clearCovers,
          operation: () async {
            await ref.read(databaseProvider).clearCovers();
          },
        );
  }
}

@riverpod
class ReclaimSpace extends _$ReclaimSpace {
  @override
  Future<ClearOperationStatus> build() async {
    final state = await ref.watch(clearOperationProvider.future);

    if (state.type == .reclaimSpace) {
      return state.status;
    }

    if (state.status != .idle) {
      return .busy;
    }

    return .idle;
  }

  Future<void> reclaimSpace() async {
    await ref
        .read(clearOperationProvider.notifier)
        .performOperation(
          type: .reclaimSpace,
        );
  }
}

enum ClearOperationStatus {
  idle,
  busy,
  inProgress,
  reclaimingSpace,
  error,
}

enum ClearOperationType {
  none,
  clearDatabase,
  clearDownloads,
  clearCovers,
  reclaimSpace,
}

@freezed
sealed class ClearOperationState with _$ClearOperationState {
  const factory ClearOperationState({
    @Default(ClearOperationStatus.idle) ClearOperationStatus status,
    @Default(ClearOperationType.none) ClearOperationType type,
  }) = _ClearOperationState;
}

@riverpod
class ClearOperation extends _$ClearOperation {
  @override
  Future<ClearOperationState> build() async {
    final syncing = ref.watch(
      syncManagerProvider.select((sync) => sync is SyncingState),
    );
    final downloading = ref.watch(
      downloadManagerProvider.select(
        (down) => down.hasValue && down.value!.downloadQueue.isNotEmpty,
      ),
    );

    return ClearOperationState(
      status: syncing || downloading ? .busy : .idle,
    );
  }

  Future<void> performOperation({
    required ClearOperationType type,
    Future<void> Function()? operation,
  }) async {
    final current = await future;
    if (current.status != .idle) return;

    final newState = ClearOperationState(
      status: .inProgress,
      type: type,
    );

    try {
      if (operation != null) {
        state = AsyncData(newState);
        await operation();
      }
      state = AsyncData(newState.copyWith(status: .reclaimingSpace));
      await ref.read(databaseProvider).vacuum();
      state = const AsyncData(ClearOperationState());
    } catch (e) {
      state = AsyncData(newState.copyWith(status: .error));
    }
  }
}
