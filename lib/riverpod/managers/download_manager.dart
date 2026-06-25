import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/settings/download_settings.dart';
import 'package:kover/riverpod/repository/download_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:kover/utils/lifecycle.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_manager.freezed.dart';
part 'download_manager.g.dart';

@freezed
sealed class DownloadManagerState with _$DownloadManagerState {
  const DownloadManagerState._();

  const factory DownloadManagerState({@Default({}) Set<int> downloadQueue}) =
      _DownloadManagerState;

  factory DownloadManagerState.fromJson(Map<String, Object?> json) =>
      _$DownloadManagerStateFromJson(json);
}

@Riverpod(keepAlive: true)
@JsonPersist()
class DownloadManager extends _$DownloadManager {
  final Map<int, CancelableOperation<void>> _activeTasks = {};

  @override
  Future<DownloadManagerState> build() async {
    listenSelf((previous, next) async {
      await _processQueue();
    });
    _listenConnectivity();
    _listenAppLifecycle();
    _listenSyncManager();
    _listenDownloadSettings();

    await persist(ref.watch(storageProvider.future)).future;

    return state.value ?? const DownloadManagerState();
  }

  Future<void> enqueue(int chapterId) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        downloadQueue: {...current.downloadQueue, chapterId},
      ),
    );
    log.info(
      'enqueued chapter for download',
      attributes: {
        'chapter_id': .int(chapterId),
      },
    );
  }

  Future<void> enqueueVolume(int volumeId) async {
    final current = await future;
    final ids = await ref
        .read(volumesRepositoryProvider)
        .getChapterIds(volumeId: volumeId);
    state = AsyncData(
      current.copyWith(
        downloadQueue: {...current.downloadQueue, ...ids},
      ),
    );
    log.info(
      'enqueued volume for download',
      attributes: {
        'volume_id': .int(volumeId),
        'chapter_count': .int(ids.length),
      },
    );
  }

  Future<void> enqueueSeries(int seriesId) async {
    final current = await future;
    final ids = await ref
        .read(seriesRepositoryProvider)
        .allChapterIds(seriesId: seriesId);
    state = AsyncData(
      current.copyWith(
        downloadQueue: {...current.downloadQueue, ...ids},
      ),
    );
    log.info(
      'enqueued series for download',
      attributes: {
        'series_id': .int(seriesId),
        'chapter_count': .int(ids.length),
      },
    );
  }

  Future<void> cancel(int chapterId) async {
    final current = await future;

    await _activeTasks[chapterId]?.cancel();
    _activeTasks.remove(chapterId);

    final newQueue = Set<int>.from(current.downloadQueue)..remove(chapterId);
    state = AsyncData(current.copyWith(downloadQueue: newQueue));
  }

  Future<void> cancelAll() async {
    final current = await future;

    await _clearActiveTasks();

    state = AsyncData(current.copyWith(downloadQueue: {}));
  }

  Future<void> deleteChapter(int chapterId) async {
    await ref
        .read(downloadRepositoryProvider)
        .deleteChapter(chapterId: chapterId);
  }

  Future<void> deleteVolume(int volumeId) async {
    final ids = await ref
        .read(volumesRepositoryProvider)
        .getChapterIds(volumeId: volumeId);

    await _clearIds(ids);
    await ref.read(downloadRepositoryProvider).deleteVolume(volumeId);
  }

  Future<void> deleteSeries(int seriesId) async {
    final ids = await ref
        .read(seriesRepositoryProvider)
        .allChapterIds(seriesId: seriesId);

    await _clearIds(ids);
    await ref.read(downloadRepositoryProvider).deleteSeries(seriesId: seriesId);
  }

  Future<void> _processQueue() async {
    if (ref.read(hasConnectionProvider).value != true ||
        ref.read(syncManagerProvider) is SyncingState) {
      return;
    }

    final current = await future;

    final concurrentDownloads = await ref.read(
      downloadSettingsProvider.selectAsync(
        (state) => state.concurrentDownloads,
      ),
    );

    final activeCount = _activeTasks.length;

    final toStart = current.downloadQueue
        .where((i) => !_activeTasks.containsKey(i))
        .take(concurrentDownloads - activeCount);

    for (final chapterId in toStart) {
      log.info(
        'starting download for chapter',
        attributes: {
          'chapter_id': .int(chapterId),
        },
      );

      unawaited(_startDownload(chapterId));
    }
  }

  Future<void> _clearActiveTasks() async {
    final tasks = _activeTasks.values.toList();

    // Clear the active tasks map before awaiting cancellation to avoid
    // modifying the map while iterating.
    _activeTasks.clear();

    for (final task in tasks) {
      await task.cancel();
    }
  }

  Future<void> _startDownload(int chapterId) async {
    final repo = ref.read(downloadRepositoryProvider);

    final task = CancelableOperation.fromFuture(
      repo
          .downloadChapter(chapterId: chapterId)
          .timeout(
            const Duration(minutes: 10),
          ),
    );

    _activeTasks[chapterId] = task;

    try {
      await task.value;
    } catch (e, stacktrace) {
      log.error(
        'download failed for chapter',
        error: e,
        stacktrace: stacktrace,
        attributes: {
          'chapter_id': .int(chapterId),
        },
      );
    } finally {
      _activeTasks.remove(chapterId);

      if (!task.isCanceled) {
        log.info(
          'download completed for chapter',
          attributes: {
            'chapterId': .int(chapterId),
          },
        );
        final current = await future;
        final newQueue = Set<int>.from(current.downloadQueue)
          ..remove(chapterId);
        state = AsyncData(current.copyWith(downloadQueue: newQueue));
      }
    }
  }

  Future<void> _clearIds(List<int> chapterIds) async {
    final current = await future;
    final active = _activeTasks.keys
        .where((k) => chapterIds.contains(k))
        .toList();
    for (final k in active) {
      await _activeTasks[k]!.cancel();
      _activeTasks.remove(k);
    }
    final newQueue = Set<int>.from(current.downloadQueue)
      ..removeAll(chapterIds);
    state = AsyncData(current.copyWith(downloadQueue: newQueue));
  }

  void _listenSyncManager() {
    ref.listen(syncManagerProvider, (previous, next) async {
      if (next is SyncingState && previous is! SyncingState) {
        await _clearActiveTasks();
      } else if (next is! SyncingState) {
        await _processQueue();
      }
    });
  }

  void _listenConnectivity() {
    ref.listen(hasConnectionProvider, (prev, next) {
      next.whenData((good) async {
        if (prev != null && good != prev.value) {
          await _clearActiveTasks();
          if (good) await _processQueue();
        }
      });
    });
  }

  void _listenAppLifecycle() async {
    final observer = LifecycleOnResumeObserver(
      onResume: () async {
        await _clearActiveTasks();
        await _processQueue();
      },
    );
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  }

  void _listenDownloadSettings() {
    ref.listen(
      downloadSettingsProvider,
      (prev, next) async {
        next.whenData((next) async {
          if (next.concurrentDownloads != prev?.value?.concurrentDownloads) {
            await _clearActiveTasks();
            await _processQueue();
          }
        });
      },
    );
  }
}
