import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/pages/reader/image_reader/image_measure_root.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/utils/headless_measure_pipeline.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_vertical_reader.freezed.dart';
part 'image_vertical_reader.g.dart';

@freezed
sealed class VerticalReaderCacheState with _$VerticalReaderCacheState {
  const factory VerticalReaderCacheState({
    required Map<int, double> cachedHeights,
  }) = _VerticalReaderCacheState;
}

@riverpod
class VerticalReaderCache extends _$VerticalReaderCache {
  final _pipeline = HeadlessMeasurePipeline();

  bool _measuring = false;
  double? _measuredWidth;

  @override
  Future<VerticalReaderCacheState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    ref.onDispose(_pipeline.dispose);

    return const VerticalReaderCacheState(cachedHeights: {});
  }

  /// Measures the heights of all pages before [currentPage] that are not
  /// cached yet. Safe to call repeatedly;
  Future<void> measurePreviousPages({
    required int currentPage,
    required Size viewport,
    required double devicePixelRatio,
    required double horizontalPadding,
    required double refreshRate,
  }) async {
    if (viewport.isEmpty) return;

    if (_measuring) return;
    _measuring = true;

    try {
      // Heights depend on the fitted width; drop the cache when the viewport
      // width changed so stale heights never mix with fresh ones.
      if (_measuredWidth != viewport.width) {
        _measuredWidth = viewport.width;
        state = const .data(
          VerticalReaderCacheState(cachedHeights: {}),
        );
      }

      final current = await future;
      final missingPages = List.generate(
        currentPage,
        (index) => index,
      ).where((page) => !current.cachedHeights.containsKey(page));

      if (missingPages.isEmpty) return;

      _pipeline.attach(
        size: viewport,
        devicePixelRatio: devicePixelRatio,
      );

      final stopwatch = Stopwatch()..start();
      final maxChunkDuration = Duration(
        milliseconds: (1000 / refreshRate).round(),
      );

      for (final page in missingPages) {
        if (!ref.mounted) return;

        final current = await future;
        if (!current.cachedHeights.containsKey(page)) {
          await _measurePage(
            page,
            horizontalPadding: horizontalPadding,
          );
        }

        // Yield to the event loop periodically to keep the UI responsive.
        if (stopwatch.elapsed >= maxChunkDuration) {
          stopwatch.reset();
          if (SchedulerBinding.instance.hasScheduledFrame) {
            await SchedulerBinding.instance.endOfFrame;
          } else {
            await Future<void>.delayed(0.ms);
          }
        }
      }
    } on MeasureTreeBuildException catch (e, stacktrace) {
      log.error(
        'measure widget failed to build',
        error: e,
        stacktrace: stacktrace,
      );
    } finally {
      _measuring = false;
    }
  }

  Future<void> _measurePage(
    int page, {
    required double horizontalPadding,
  }) async {
    final image = await ref.read(
      imagePageProvider(chapterId: chapterId, page: page).future,
    );

    final codec = await ui.instantiateImageCodec(image.data);
    final frame = await codec.getNextFrame();
    try {
      if (!_pipeline.isAttached) {
        log.warning(
          'pipeline detached during measurement',
          attributes: {'page': page},
        );
        return;
      }

      final height = _pipeline
          .measure(
            ImageMeasureRoot(
              image: frame.image,
              horizontalPadding: horizontalPadding,
            ),
          )
          .height;

      if (height > 0) {
        await cachePageHeight(page, height);
      }
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  Future<void> cachePageHeight(int page, double height) async {
    final current = await future;

    state = AsyncValue.data(
      current.copyWith(
        cachedHeights: {
          ...current.cachedHeights,
          page: height,
        },
      ),
    );
  }

  void clearCache() {
    state = const AsyncValue.data(
      VerticalReaderCacheState(cachedHeights: {}),
    );
  }
}
