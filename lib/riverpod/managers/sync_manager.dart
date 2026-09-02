import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/providers/settings/download_settings.dart';
import 'package:kover/sync/sync_worker.dart';
import 'package:kover/utils/lifecycle.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_manager.freezed.dart';
part 'sync_manager.g.dart';

@freezed
sealed class SyncPhase with _$SyncPhase {
  const factory allSeries() = AllSeries;
  const factory metadata() = Metadata;
  const factory tocs() = Tocs;
  const factory onDeck() = OnDeck;
  const factory recentlyAdded() = RecentlyAdded;
  const factory recentlyUpdated() = RecentlyUpdated;
  const factory libraries() = Libraries;
  const factory progress() = Progress;
  const factory covers() = Covers;
  const factory collections() = Collections;
  const factory readingLists() = ReadingLists;
  const factory smartFilters() = SmartFilters;
  const factory sidenav() = Sidenav;
  const factory dashboard() = Dashboard;
  const factory refreshServerSettings() = RefreshServerSettings;
  const factory refreshServerFonts() = RefreshServerFonts;
  const factory refreshMetadata({required int seriesId}) = RefreshMetadata;
  const factory refreshCovers({required int seriesId}) = RefreshCovers;
  const factory refreshToc({required int chapterId}) = RefreshToc;
}

@Riverpod(keepAlive: true)
Future<SyncWorker> syncWorker(Ref ref) async {
  final credentials = await ref.watch(credentialsProvider.future);

  final worker = await SyncWorker.spawn(
    url: credentials.url!,
    key: credentials.apiKey!,
    customHeaders: credentials.customHeaders,
  );

  // 2. Automatically clean up the isolate
  ref.onDispose(() => worker.close());

  return worker;
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
  static const _maxConcurrentPhases = 4;

  final List<Set<SyncPhase>> _queuedPhases = [];
  final Set<SyncPhase> _runningPhases = {};

  @override
  SyncState build() {
    _listenCredentials();
    _listenConnectivity();
    _listenAppLifecycle();

    return const SyncState.idle();
  }

  /// Perform full sync with server
  Future<void> fullSync() async {
    final settings = await ref.read(downloadSettingsProvider.future);

    _enqueuePhases({const .allSeries()});
    _enqueuePhases({
      const .progress(),
      const .libraries(),
      const .recentlyUpdated(),
      const .recentlyAdded(),
      const .readingLists(),
      const .sidenav(),
      const .dashboard(),
      const .smartFilters(),
    });
    _enqueuePhases({
      const .onDeck(),
      const .collections(),
      const .metadata(),
      const .tocs(),
      const .refreshServerSettings(),
      const .refreshServerFonts(),
      if (settings.downloadCovers) const .covers(),
    });
  }

  /// Sync libraries
  void syncLibraries() {
    _enqueuePhases({const .libraries()});
  }

  /// Sync collections
  void syncCollections() {
    _enqueuePhases({const .collections()});
  }

  /// Sync reading lists
  void syncReadingLists() {
    _enqueuePhases({const .readingLists()});
  }

  /// Sync progress
  void syncProgress() {
    _enqueuePhases({const .progress()});
  }

  /// Refresh metadata and details for series [seriesId]
  void refreshMetadataAndDetails({required int seriesId}) {
    _enqueuePhases({SyncPhase.refreshMetadata(seriesId: seriesId)});
  }

  /// Refresh covers for series [seriesId]
  void refreshCovers({required int seriesId}) {
    _enqueuePhases({SyncPhase.refreshCovers(seriesId: seriesId)});
  }

  /// Refresh chapter toc for chapter [chapterId]
  void refreshChapterToc({required int chapterId}) {
    _enqueuePhases({SyncPhase.refreshToc(chapterId: chapterId)});
  }

  void _enqueuePhases(Set<SyncPhase> phases) {
    final missingPhases = phases
        .where(
          (phase) =>
              !_runningPhases.contains(phase) &&
              !_queuedPhases.any((queued) => queued.contains(phase)),
        )
        .toSet();
    if (missingPhases.isEmpty) return;
    _queuedPhases.add(missingPhases);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_runningPhases.isNotEmpty || _queuedPhases.isEmpty) return;

    while (_queuedPhases.isNotEmpty) {
      final nextPhases = _queuedPhases.removeAt(0);
      final batch = nextPhases.take(_maxConcurrentPhases);
      final remaining = nextPhases.skip(_maxConcurrentPhases);
      if (remaining.isNotEmpty) {
        _queuedPhases.insert(0, remaining.toSet());
      }

      await Future.wait(
        batch.map((phase) async {
          await _runPhase(phase);
        }),
      );
    }

    state = const SyncState.idle();
  }

  Future<void> _runPhase(
    SyncPhase phase,
  ) async {
    final hasUser = ref.read(currentUserProvider).hasValue;
    final hasConnection = ref.read(hasConnectionProvider).value ?? false;
    if (!hasUser || !hasConnection || _runningPhases.contains(phase)) return;

    _runningPhases.add(phase);
    state = SyncState.syncing(phases: Set.unmodifiable(_runningPhases));

    var failed = false;
    try {
      final worker = await ref.read(syncWorkerProvider.future);
      await worker.runPhase(phase);
    } catch (e, stacktrace) {
      failed = true;
      state = SyncState.error(phase: phase, error: e);
      log.error(
        'failed sync phase',
        error: e,
        stacktrace: stacktrace,
        attributes: {'phase': phase},
      );
    } finally {
      _runningPhases.remove(phase);
      if (!failed && _runningPhases.isNotEmpty) {
        state = SyncState.syncing(phases: Set.unmodifiable(_runningPhases));
      }
    }
  }

  void _listenCredentials() {
    ref.listen(credentialsProvider, (prev, next) async {
      if (next.hasValue && next.value != prev?.value) {
        await fullSync();
      }
    });
  }

  void _listenConnectivity() {
    ref.listen(hasConnectionProvider, (prev, next) {
      next.whenData((good) async {
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
