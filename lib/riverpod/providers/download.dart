import 'package:kover/models/download_status.dart';
import 'package:kover/riverpod/managers/download_manager/download_manager.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/riverpod/repository/download_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download.g.dart';

/// Whether every page of [chapterId] is stored locally
@riverpod
Stream<bool> chapterDownloaded(
  Ref ref, {
  required int chapterId,
}) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchIsChapterDownloaded(chapterId: chapterId).distinct();
}

/// The download progress percent for chapter [chapterId]
@riverpod
Stream<double> chapterDownloadProgress(
  Ref ref, {
  required int chapterId,
}) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchDownloadProgress(chapterId: chapterId).distinct();
}

/// The download status for chapter [chapterId]
@riverpod
Future<DownloadStatus?> chapterDownloadStatus(
  Ref ref, {
  required int chapterId,
}) async {
  final inQueueFuture = ref.watch(
    downloadManagerProvider.selectAsync(
      (state) => state.downloadQueue.contains(chapterId),
    ),
  );
  final downloadProgressFuture = ref.watch(
    chapterDownloadProgressProvider(chapterId: chapterId).future,
  );
  final downloadedFuture = ref.watch(
    chapterDownloadedProvider(chapterId: chapterId).future,
  );

  final inQueue = await inQueueFuture;
  final downloadProgress = await downloadProgressFuture;
  final downloaded = await downloadedFuture;

  if (downloaded) return .downloaded();
  if (downloadProgress > 0.0) return .downloading(progress: downloadProgress);
  if (inQueue) return .queued();
  return null;
}

/// Emits download progress percent for volume [volumeId]
@riverpod
Stream<double> volumeDownloadProgress(
  Ref ref, {
  required int volumeId,
}) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchVolumeDownloadProgress(volumeId: volumeId).distinct();
}

/// The download status for volume [volumeId]
@riverpod
Future<DownloadStatus?> volumeDownloadStatus(
  Ref ref, {
  required int volumeId,
}) async {
  final progress = await ref.watch(
    volumeDownloadProgressProvider(volumeId: volumeId).future,
  );
  final chapterIds = await ref.watch(
    volumeChapterIdsProvider(volumeId: volumeId).future,
  );
  final queue = await ref.watch(
    downloadManagerProvider.selectAsync((state) => state.downloadQueue),
  );

  if (progress >= 1.0) return .downloaded();
  if (progress > 0.0) return .downloading(progress: progress);
  if (chapterIds.any(queue.contains)) return .queued();
  return null;
}

/// Emits total download progress percent for all chapters belonging to series [seriesId]
@riverpod
Stream<double> seriesDownloadProgress(
  Ref ref, {
  required int seriesId,
}) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchSeriesDownloadProgress(seriesId: seriesId).distinct();
}

/// The download status for series [seriesId]
@riverpod
Future<DownloadStatus?> seriesDownloadStatus(
  Ref ref, {
  required int seriesId,
}) async {
  final progress = await ref.watch(
    seriesDownloadProgressProvider(seriesId: seriesId).future,
  );
  final chapterIds = await ref.watch(
    seriesChapterIdsProvider(seriesId: seriesId).future,
  );
  final queue = await ref.watch(
    downloadManagerProvider.selectAsync((state) => state.downloadQueue),
  );

  if (progress >= 1.0) return .downloaded();
  if (progress > 0.0) return .downloading(progress: progress);
  if (chapterIds.any(queue.contains)) return .queued();
  return null;
}
