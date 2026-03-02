import 'package:flutter/widgets.dart';
import 'package:fluvita/riverpod/providers/auth.dart';
import 'package:fluvita/riverpod/providers/connectivity.dart';
import 'package:fluvita/riverpod/providers/series.dart';
import 'package:fluvita/riverpod/repository/book_repository.dart';
import 'package:fluvita/riverpod/repository/chapters_repository.dart';
import 'package:fluvita/riverpod/repository/libraries_repository.dart';
import 'package:fluvita/riverpod/repository/reader_repository.dart';
import 'package:fluvita/riverpod/repository/series_repository.dart';
import 'package:fluvita/riverpod/repository/volumes_repository.dart';
import 'package:fluvita/riverpod/repository/want_to_read_repository.dart';
import 'package:fluvita/utils/lifecycle.dart';
import 'package:fluvita/utils/logging.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
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

  const factory SyncState.syncing({required SyncPhase phase}) = SyncingState;

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
      _syncAllSeriesDetails(),
      _syncMetadata(),
    ]);

    await _syncCovers();
  }

  /// Sync on deck, updated, and new series, as well as progress
  Future<void> partialSync() async {
    await Future.wait([
      _syncRecentlyUpdated(),
      _syncRecentlyAdded(),
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
    });
  }

  Future<void> _syncAllSeriesDetails() async {
    await _runPhase(.seriesDetails, () async {
      final seriesRepo = ref.read(seriesRepositoryProvider);

      await seriesRepo.refreshAllSeriesDetails();
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
      state = const SyncState.syncing(phase: .recentlyUpdated);
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

      await readerRepo.refreshContinuePointsAndProgress();
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

    state = SyncState.syncing(phase: phase);
    _runningPhases.add(phase);

    try {
      await callback();
    } catch (e) {
      log.e('failed phase', error: e);
      state = SyncState.error(
        phase: state.whenOrNull(syncing: (phase) => phase) ?? .none,
        error: e,
      );

      return;
    } finally {
      _runningPhases.remove(phase);
      if (_runningPhases.isEmpty) {
        state = const SyncState.idle();
      } else {
        state = SyncState.syncing(phase: _runningPhases.first);
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
          partialSync();
        }
      });
    });
  }

  void _listenAppLifecycle() {
    final observer = LifecycleOnResumeObserver(onResume: partialSync);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  }
}
