import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:kover/utils/lifecycle.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_manager.freezed.dart';
part 'sync_manager.g.dart';

enum SyncPhase {
  none,
  allSeries,
  seriesDetails,
  metadata,
  recentlyAdded,
  recentlyUpdated,
  libraries,
  progress,
  covers,
}

@freezed
sealed class SyncState with _$SyncState {
  const factory SyncState.idle() = IdleState;

  const factory SyncState.syncing({required Set<SyncPhase> phases}) = SyncingState;

  const factory SyncState.error({
    required SyncPhase phase,
    required Object error,
  }) = ErrorState;
}

@riverpod
class SyncManager extends _$SyncManager {
  bool _hasUser = false;
  bool _hasConnection = false;
  final Set<SyncPhase> _runningPhases = {};

  @override
  SyncState build() {
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
      _syncLibraries(),
      _syncProgress(),
      _syncMetadata(),
    ]);

    await _syncCovers();
  }

  /// Sync libraries
  Future<void> syncLibraries() async {
    await _syncLibraries();
  }

  /// Sync progress
  Future<void> syncProgress() async {
    await _syncProgress();
  }

  Future<void> _syncAllSeries() async {
    await _runPhase(.allSeries, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);

      await seriesRepo.refreshAllSeries();
      await seriesRepo.fetchMissingMetadata();
    });
  }

  Future<void> _syncMetadata() async {
    await _runPhase(.metadata, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);
      final bookRepo = ref.read(bookRepositoryProvider);

      await seriesRepo.fetchMissingMetadata();
      await bookRepo.fetchMissingChaptersTocs();
    });
  }

  Future<void> _syncLibraries() async {
    await _runPhase(.libraries, () async {
      final librariesRepo = ref.read(librariesRepositoryProvider);
      final wantToReadRepo = ref.read(wantToReadRepositoryProvider);

      await librariesRepo.refreshLibraries();
      await wantToReadRepo.mergeWantToRead();
    });
  }

  Future<void> _syncRecentlyUpdated() async {
    await _runPhase(.recentlyUpdated, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);

      await seriesRepo.refreshRecentlyUpdated();
      await seriesRepo.fetchMissingMetadata();
    });
  }

  Future<void> _syncRecentlyAdded() async {
    await _runPhase(.recentlyAdded, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);

      await seriesRepo.refreshRecentlyAdded();
      await seriesRepo.fetchMissingMetadata();
    });
  }

  Future<void> _syncProgress() async {
    await _runPhase(.progress, () async {
      final readerRepo = ref.read(readerRepositoryProvider);

      await readerRepo.refreshOutdatedProgress();
      await readerRepo.mergeProgress();
    });
  }

  Future<void> _syncCovers() async {
    await _runPhase(.covers, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);
      final volumesRepo = ref.read(volumesRepositoryProvider);
      final chapterRepo = ref.read(chaptersRepositoryProvider);

      await Future.wait([
        seriesRepo.fetchMissingCovers(),
        volumesRepo.fetchMissingCovers(),
        chapterRepo.fetchMissingCovers(),
      ]);
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
    ref.listen(currentUserProvider, (prev, next) {
      _hasUser = next.hasValue;

      if (next.hasError) return;

      if (prev?.value != next.value) fullSync();
    });
  }

  void _listenConnectivity() {
    ref.listen(hasConnectionProvider, (prev, next) {
      next.whenData((good) {
        _hasConnection = good;

        // skip update on first event as we are syncing already
        if (prev != null && good && good != prev.value) {
          fullSync();
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
