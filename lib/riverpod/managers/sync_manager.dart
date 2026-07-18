import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/settings/download_settings.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/collections_repository.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/reading_lists_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/server_settings_repository.dart';
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
  const factory SyncPhase.metadata() = Metadata;
  const factory SyncPhase.tocs() = Tocs;
  const factory SyncPhase.recentlyAdded() = RecentlyAdded;
  const factory SyncPhase.recentlyUpdated() = RecentlyUpdated;
  const factory SyncPhase.libraries() = Libraries;
  const factory SyncPhase.progress() = Progress;
  const factory SyncPhase.covers() = Covers;
  const factory SyncPhase.collections() = Collections;
  const factory SyncPhase.readingLists() = ReadingLists;
  const factory SyncPhase.sidenav() = Sidenav;
  const factory SyncPhase.refreshServerSettings() = RefreshServerSettings;
  const factory SyncPhase.refreshMetadata({required int seriesId}) =
      RefreshMetadata;
  const factory SyncPhase.refreshCovers({required int seriesId}) =
      RefreshCovers;
  const factory SyncPhase.refreshToc({
    required int chapterId,
  }) = RefreshToc;

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
  static const _maxConcurrentPhases = 4;

  bool _hasUser = false;
  bool _hasConnection = false;
  final List<Set<SyncPhase>> _queuedPhases = [];
  final Set<SyncPhase> _runningPhases = {};

  SyncEngine get _engine {
    final seriesRepo = ref.read(seriesRepositoryProvider);
    final bookRepo = ref.read(bookRepositoryProvider);
    final librariesRepo = ref.read(librariesRepositoryProvider);
    final wantToReadRepo = ref.read(wantToReadRepositoryProvider);
    final readerRepo = ref.read(readerRepositoryProvider);
    final volumesRepo = ref.read(volumesRepositoryProvider);
    final chaptersRepo = ref.read(chaptersRepositoryProvider);
    final serverSettingsRepo = ref.read(serverSettingsRepositoryProvider);
    final collectionsRepo = ref.read(collectionsRepositoryProvider);
    final readingListsRepo = ref.read(readingListsRepositoryProvider);

    return SyncEngine(
      seriesRepo: seriesRepo,
      bookRepo: bookRepo,
      librariesRepo: librariesRepo,
      wantToReadRepo: wantToReadRepo,
      readerRepo: readerRepo,
      volumesRepo: volumesRepo,
      chaptersRepo: chaptersRepo,
      serverSettingsRepo: serverSettingsRepo,
      collectionsRepo: collectionsRepo,
      readingListsRepo: readingListsRepo,
    );
  }

  Future<void> Function() _getCallback(SyncPhase phase) => phase.when(
    allSeries: () =>
        () async => await _engine.syncAllSeries(),
    metadata: () =>
        () async => await _engine.syncMetadata(),
    tocs: () =>
        () async => await _engine.syncTocs(),
    recentlyAdded: () =>
        () async => await _engine.syncRecentlyAdded(),
    recentlyUpdated: () =>
        () async => await _engine.syncRecentlyUpdated(),
    libraries: () =>
        () async => await _engine.syncLibraries(),
    progress: () =>
        () async => await _engine.syncProgress(),
    covers: () =>
        () async => await _engine.syncCovers(),
    collections: () =>
        () async => await _engine.syncCollections(),
    readingLists: () =>
        () async => await _engine.syncReadingLists(),
    sidenav: () =>
        () async => await _engine.syncSidenav(),
    refreshServerSettings: () =>
        () async => await _engine.refreshServerSettings(),
    refreshMetadata: (seriesId) =>
        () async => await _engine.refreshMetadataAndDetails(seriesId: seriesId),
    refreshCovers: (seriesId) =>
        () async => await _engine.refreshCovers(seriesId: seriesId),
    refreshToc: (chapterId) =>
        () async => await _engine.refreshToc(chapterId: chapterId),
  );

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
    final settings = await ref.read(downloadSettingsProvider.future);

    _enqueuePhases({const .allSeries()});
    _enqueuePhases({
      const .progress(),
      const .libraries(),
      const .recentlyUpdated(),
      const .recentlyAdded(),
      const .collections(),
      const .readingLists(),
      const .metadata(),
      const .tocs(),
      const .refreshServerSettings(),
      const .sidenav(),
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
    final missingPhases = phases.where(
      (phase) =>
          !_runningPhases.contains(phase) &&
          !_queuedPhases.any((queued) => queued.contains(phase)),
    );
    _queuedPhases.add(missingPhases.toSet());
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
          final callback = _getCallback(phase);
          await _runPhase(phase, callback);
        }),
      );
    }

    state = const SyncState.idle();
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

  void _listenUser() {
    ref.listen(currentUserProvider, (prev, next) async {
      _hasUser = next.hasValue;
      if (next.hasError) return;
      if (prev != null && next.hasValue && prev.value != next.value) {
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
