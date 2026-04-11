import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:kover/sync/sync_engine.dart';
import 'package:kover/utils/lifecycle.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_manager.freezed.dart';
part 'sync_manager.g.dart';

@freezed
sealed class SyncPhase with _$SyncPhase {
  const SyncPhase._();

  const factory SyncPhase.allSeries() = AllSeries;
  const factory SyncPhase.seriesDetails() = SeriesDetails;
  const factory SyncPhase.metadata() = Metadata;
  const factory SyncPhase.recentlyAdded() = RecentlyAdded;
  const factory SyncPhase.recentlyUpdated() = RecentlyUpdated;
  const factory SyncPhase.libraries() = Libraries;
  const factory SyncPhase.progress() = Progress;
  const factory SyncPhase.covers() = Covers;
  const factory SyncPhase.refreshCovers({required int seriesId}) =
      RefreshCovers;

  factory SyncPhase.fromJson(Map<String, dynamic> json) =>
      _$SyncPhaseFromJson(json);
}

@freezed
sealed class SyncState with _$SyncState {
  const factory SyncState.idle() = IdleState;

  const factory SyncState.syncing({required Set<SyncPhase> phases}) =
      SyncingState;

  const factory SyncState.error({
    required SyncPhase phase,
    required Object error,
  }) = ErrorState;
}

@Riverpod(keepAlive: true)
class SyncManager extends _$SyncManager {
  bool _hasUser = false;
  bool _hasConnection = false;
  final Set<SyncPhase> _runningPhases = {};
  SyncEngine get _engine {
    final seriesRepo = ref.read(seriesRepositoryProvider);
    final bookRepo = ref.read(bookRepositoryProvider);
    final librariesRepo = ref.read(librariesRepositoryProvider);
    final wantToReadRepo = ref.read(wantToReadRepositoryProvider);
    final readerRepo = ref.read(readerRepositoryProvider);
    final volumesRepo = ref.read(volumesRepositoryProvider);
    final chaptersRepo = ref.read(chaptersRepositoryProvider);

    return SyncEngine(
      seriesRepo: seriesRepo,
      bookRepo: bookRepo,
      librariesRepo: librariesRepo,
      wantToReadRepo: wantToReadRepo,
      readerRepo: readerRepo,
      volumesRepo: volumesRepo,
      chaptersRepo: chaptersRepo,
    );
  }

  @override
  SyncState build() {
    _hasUser = ref.read(currentUserProvider).hasValue;
    _hasConnection = ref.read(hasConnectionProvider).value ?? false;

    _listenUser();
    _listenConnectivity();
    _listenAppLifecycle();

    return const SyncState.idle();
  }

  /// Perform full sync with server
  Future<void> fullSync() async {
    await _syncAllSeries();

    await Future.wait([
      _syncRecentlyUpdated(),
      _syncRecentlyAdded(),
      syncLibraries(),
      syncProgress(),
      _syncMetadata(),
    ]);

    await _syncCovers();
  }

  /// Sync libraries
  Future<void> syncLibraries() async {
    await _runPhase(const .libraries(), () async {
      await _engine.syncLibraries();
    });
  }

  /// Sync progress
  Future<void> syncProgress() async {
    await _runPhase(const .progress(), () async {
      await _engine.syncProgress();
    });
  }

  Future<void> _syncAllSeries() async {
    await _runPhase(const .allSeries(), () async {
      await _engine.syncAllSeries();
    });
  }

  Future<void> _syncMetadata() async {
    await _runPhase(const .metadata(), () async {
      await _engine.syncMetadata();
    });
  }

  Future<void> _syncRecentlyUpdated() async {
    await _runPhase(const .recentlyUpdated(), () async {
      await _engine.syncRecentlyUpdated();
    });
  }

  Future<void> _syncRecentlyAdded() async {
    await _runPhase(const .recentlyAdded(), () async {
      await _engine.syncRecentlyAdded();
    });
  }

  Future<void> _syncCovers() async {
    await _runPhase(const .covers(), () async {
      await _engine.syncCovers();
    });
  }

  Future<void> refreshCovers({required int seriesId}) async {
    await _runPhase(.refreshCovers(seriesId: seriesId), () async {
      await _engine.refreshCovers(seriesId: seriesId);
    });
  }

  Future<void> _runPhase(
    SyncPhase phase,
    FutureOr<void> Function() callback,
  ) async {
    if (!_hasUser || !_hasConnection || _runningPhases.contains(phase)) return;

    _runningPhases.add(phase);
    state = SyncState.syncing(phases: Set.unmodifiable(_runningPhases));

    var failed = false;
    try {
      await callback();
    } catch (e) {
      failed = true;
      log.e('failed phase', error: e);
      state = SyncState.error(phase: phase, error: e);
    } finally {
      _runningPhases.remove(phase);
      if (!failed) {
        if (_runningPhases.isEmpty) {
          state = const SyncState.idle();
        } else {
          state = SyncState.syncing(phases: Set.unmodifiable(_runningPhases));
        }
      }
    }
  }

  void _listenUser() {
    ref.listen(currentUserProvider, (prev, next) async {
      _hasUser = next.hasValue;
      if (next.hasError) return;
      if (prev != null && next.hasValue && prev.value != next.value) {
        await ref.read(databaseProvider).clearDb();
        await fullSync();
      }
    });
  }

  void _listenConnectivity() {
    ref.listen(hasConnectionProvider, (prev, next) {
      next.whenData((good) async {
        _hasConnection = good;

        // skip update on first event as we are syncing already
        if (prev != null && good && good != prev.value) {
          await fullSync();
        }
      });
    });
  }

  void _listenAppLifecycle() {
    final observer = LifecycleOnResumeObserver(onResume: fullSync);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  }
}
