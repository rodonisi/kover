import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/progress_model.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
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
    required int volumeId,
    required String title,
    required int totalPages,
    required int initialPage,
    String? bookScrollId,
  }) = _ReaderState;

  factory ReaderState.fromJson(Map<String, Object?> json) =>
      _$ReaderStateFromJson(json);
}

@riverpod
class Reader extends _$Reader {
  Timer? _saveProgressDebounce;

  @override
  Future<ReaderState> build({required int seriesId, int? chapterId}) async {
    var chapter = await ref.read(
      continuePointProvider(seriesId: seriesId).future,
    );

    if (chapterId != null) {
      chapter = await ref.watch(
        chapterProvider(chapterId: chapterId).future,
      );
    }

    final progress = await ref.read(
      bookProgressProvider(chapterId: chapter.id).future,
    );

    final series = await ref.read(
      seriesProvider(seriesId: seriesId).future,
    );

    return ReaderState(
      libraryId: series.libraryId,
      series: series,
      volumeId: chapter.volumeId,
      chapter: chapter,
      title: chapter.title,
      totalPages: chapter.pages,
      initialPage: progress?.pageNum ?? 0,
      bookScrollId: progress?.bookScrollId,
    );
  }

  Future<void> saveProgress({required int page, String? scrollId}) async {
    if (state.isLoading) return;
    final current = await future;

    _saveProgressDebounce?.cancel();

    _saveProgressDebounce = Timer(500.ms, () async {
      log.d(
        'Saving progress: page=$page, scrollId=$scrollId, chapter=${current.chapter.id}',
      );

      if (!ref.mounted) return;

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

      if (page >= current.totalPages - 1) {
        await markComplete();
      }
    });
  }

  Future<void> markComplete() async {
    if (state.isLoading) return;
    final current = await future;
    await ref
        .read(readerRepositoryProvider)
        .markChapterRead(current.chapter.id);
  }
}

@riverpod
Future<ReadDirection> readDirection(
  Ref ref, {
  required int seriesId,
  int? chapterId,
}) async {
  final format =
      ref.watch(
        readerProvider(seriesId: seriesId, chapterId: chapterId).select(
          (state) => state.value?.series.format,
        ),
      ) ??
      Format.unknown;

  return switch (format) {
    .epub => (await ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId).future,
    )).readDirection,
    .archive => (await ref.watch(
      imageReaderSettingsProvider(seriesId: seriesId).future,
    )).readDirection,
    .unknown => .rightToLeft,
  };
}
