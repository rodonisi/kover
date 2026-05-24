import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/progress_model.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/repository/download_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader.g.dart';

/// Whether [chapterId] can be read in the current state.
/// Returns false if there is no connectivity and the chapter is not downloaded.
@riverpod
Stream<bool> canReadChapter(Ref ref, int chapterId) {
  final hasConnection = ref.watch(hasConnectionProvider).value ?? false;
  final repo = ref.watch(downloadRepositoryProvider);
  return repo
      .watchIsChapterDownloaded(chapterId: chapterId)
      .map((isDownloaded) => isDownloaded || hasConnection);
}

/// Whether the [seriesId] can be read in the current state.
/// Returns false if there is no connectivity and the continue point is
/// not downloaded.
@riverpod
Stream<bool> canReadSeries(Ref ref, int seriesId) {
  final hasConnection = ref.watch(hasConnectionProvider).value ?? false;

  final chapter = ref
      .watch(continuePointStreamProvider(seriesId: seriesId))
      .value;

  if (chapter == null) return Stream.value(hasConnection);

  final repo = ref.watch(downloadRepositoryProvider);

  return repo
      .watchIsChapterDownloaded(chapterId: chapter.id)
      .map((isDownloaded) => isDownloaded || hasConnection);
}

/// Fetch continue point for [seriesId] asynchronously. Guarantees a value
/// is returned and does not update until manually invalidated or disposed.
@riverpod
Future<ChapterModel> continuePoint(Ref ref, {required int seriesId}) async {
  final repo = ref.watch(readerRepositoryProvider);
  return await repo.getContinuePoint(seriesId: seriesId);
}

/// Watch continue point for [seriesId], reacting to changes automatically.
@riverpod
Stream<ChapterModel> continuePointStream(
  Ref ref, {
  required int seriesId,
}) async* {
  final repo = ref.watch(readerRepositoryProvider);
  yield* repo.watchContinuePoint(seriesId: seriesId);
}

/// Watch the progress of the continue point for the given [seriesId]
@riverpod
Stream<double> continuePointProgress(Ref ref, {required int seriesId}) async* {
  final repo = ref.watch(readerRepositoryProvider);
  yield* repo.watchContinuePointProgress(seriesId: seriesId).distinct();
}

/// Watch continue point for the given volume [volumeId]
@riverpod
Stream<ChapterModel> volumeContinuePoint(
  Ref ref, {
  required int volumeId,
}) async* {
  final repo = ref.watch(readerRepositoryProvider);
  yield* repo.watchVolumeContinuePoint(volumeId: volumeId);
}

@riverpod
Future<ProgressModel?> bookProgress(Ref ref, {required int chapterId}) async {
  final repo = ref.watch(readerRepositoryProvider);
  return await repo.getProgress(chapterId);
}

@riverpod
Stream<ChapterModel?> prevChapter(
  Ref ref, {
  int? seriesId,
  int? volumeId,
  int? chapterId,
}) async* {
  if (seriesId == null || chapterId == null) {
    yield null;
    return;
  }
  final repo = ref.watch(readerRepositoryProvider);
  yield* repo
      .watchPrevChapter(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      )
      .distinct();
}

@riverpod
Stream<ChapterModel?> nextChapter(
  Ref ref, {
  int? seriesId,
  int? volumeId,
  int? chapterId,
}) async* {
  if (seriesId == null || chapterId == null) {
    yield null;
    return;
  }
  final repo = ref.watch(readerRepositoryProvider);
  yield* repo
      .watchNextChapter(
        seriesId: seriesId,
        volumeId: volumeId,
        chapterId: chapterId,
      )
      .distinct();
}

@riverpod
class MarkSeriesRead extends _$MarkSeriesRead {
  @override
  void build({required int seriesId}) {}

  Future<void> markRead() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markSeriesRead(seriesId);
    syncManager.syncProgress();
  }

  Future<void> markUnread() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markSeriesUnread(seriesId);
    syncManager.syncProgress();
  }
}

@riverpod
class MarkVolumeRead extends _$MarkVolumeRead {
  @override
  void build({required int volumeId}) {}

  Future<void> markRead() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markVolumeRead(volumeId);
    syncManager.syncProgress();
  }

  Future<void> markUnread() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markVolumeUnread(volumeId);
    syncManager.syncProgress();
  }
}

@riverpod
class MarkChapterRead extends _$MarkChapterRead {
  @override
  void build({required int chapterId}) {}

  Future<void> markRead() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markChapterRead(chapterId);
    syncManager.syncProgress();
  }

  Future<void> markUnread() async {
    final repo = ref.read(readerRepositoryProvider);
    final syncManager = ref.read(syncManagerProvider.notifier);

    await repo.markChapterUnread(chapterId);
    syncManager.syncProgress();
  }
}
