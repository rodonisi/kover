import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/progress_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader.freezed.dart';
part 'reader.g.dart';

@freezed
sealed class ReaderState with _$ReaderState {
  const ReaderState._();

  const factory ReaderState({
    required int libraryId,
    required SeriesModel series,
    required ChapterModel chapter,
    int? readingListId,
    required int volumeId,
    required String title,
    required int totalPages,
    required int initialPage,
    String? bookScrollId,
  }) = _ReaderState;
}

@riverpod
Future<SeriesModel> readerSeries(
  Ref ref, {
  required int seriesId,
}) async {
  final repo = ref.watch(seriesRepositoryProvider);
  return repo.getSeries(seriesId: seriesId);
}

@riverpod
Future<ChapterModel> readerChapter(
  Ref ref, {
  required int seriesId,
  required int chapterId,
}) async {
  final repo = ref.watch(chaptersRepositoryProvider);
  return repo.getChapter(chapterId: chapterId);
}

@riverpod
Future<ProgressModel?> readerProgress(
  Ref ref, {
  required int seriesId,
  required int chapterId,
}) async {
  final repo = ref.watch(readerRepositoryProvider);
  final chapter = await ref.read(
    readerChapterProvider(seriesId: seriesId, chapterId: chapterId).future,
  );

  return repo.getProgress(chapter.id);
}

@riverpod
class Reader extends _$Reader {
  Timer? _saveProgressDebounce;
  KeepAliveLink? _saveProgressKeepAlive;

  @override
  Future<ReaderState> build({
    required int seriesId,
    required int chapterId,
    required int? readingListId,
  }) async {
    final seriesFuture = ref.read(
      readerSeriesProvider(seriesId: seriesId).future,
    );
    final chapterFuture = ref.read(
      readerChapterProvider(seriesId: seriesId, chapterId: chapterId).future,
    );
    final progressFuture = ref.read(
      readerProgressProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    final series = await seriesFuture;
    final chapter = await chapterFuture;
    final progress = await progressFuture;

    final initialPage = progress?.pageNum ?? 0;

    return ReaderState(
      libraryId: series.libraryId,
      series: series,
      volumeId: chapter.volumeId,
      chapter: chapter,
      readingListId: readingListId,
      title: chapter.title,
      totalPages: chapter.pages,
      initialPage: initialPage.clamp(0, chapter.pages - 1),
      bookScrollId: progress?.bookScrollId,
    );
  }

  Future<void> saveProgress({
    required int page,
    String? scrollId,
    bool handleCompletion = true,
  }) async {
    final current = await future;

    if (!ref.mounted) return;

    _saveProgressDebounce?.cancel();
    _saveProgressKeepAlive?.close();

    final link = ref.keepAlive();
    _saveProgressKeepAlive = link;

    _saveProgressDebounce = Timer(100.ms, () async {
      try {
        if (!ref.mounted) return;

        if (handleCompletion && page >= current.totalPages - 1) {
          await markComplete();
          return;
        }

        await ref
            .read(readerRepositoryProvider)
            .saveProgress(
              ProgressModel(
                libraryId: current.libraryId,
                seriesId: current.series.id,
                volumeId: current.volumeId,
                chapterId: current.chapter.id,
                pageNum: page.clamp(0, current.totalPages - 1),
                bookScrollId: scrollId,
              ),
            );

        log.debug(
          'saved progress',
          attributes: {
            'page': page,
            'scroll_id': scrollId ?? 'null',
            'chapter_id': current.chapter.id,
          },
        );
      } finally {
        link.close();
        if (identical(_saveProgressKeepAlive, link)) {
          _saveProgressKeepAlive = null;
        }
      }
    });
  }

  Future<void> markComplete() async {
    if (state.isLoading) return;
    final current = await future;

    await ref
        .read(readerRepositoryProvider)
        .markChapterRead(current.chapter.id);

    log.debug(
      'marked chapter as read',
      attributes: {
        'chapter_id': current.chapter.id,
      },
    );
  }
}
