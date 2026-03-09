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

@riverpod
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

    final concurrentDownloads = (await ref.watch(
      downloadSettingsProvider.future,
    )).concurrentDownloads;

    while (_activeTasks.length < concurrentDownloads &&
        (state.value?.downloadQueue.isNotEmpty ?? false)) {
      final nextId = state.value!.downloadQueue
          .where((i) => !_activeTasks.containsKey(i))
          .firstOrNull;

      if (nextId == null) break;

      log.d('Starting download for chapter $nextId');

      await _startDownload(nextId);
    }
  }

  Future<void> _clearActiveTasks() async {
    for (final task in _activeTasks.values) {
      await task.cancel();
    }
    _activeTasks.clear();
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
    } catch (e) {
      log.e('Download failed for chapter $chapterId', error: e);
    } finally {
      _activeTasks.remove(chapterId);

      log.d('Download completed for chapter $chapterId');
      final current = await future;
      final newQueue = Set<int>.from(current.downloadQueue)..remove(chapterId);
      state = AsyncData(current.copyWith(downloadQueue: newQueue));
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
}
