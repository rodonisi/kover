import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_spreads_reader.freezed.dart';
part 'image_spreads_reader.g.dart';

@freezed
sealed class SpreadsState with _$SpreadsState {
  const factory SpreadsState({
    required List<List<int>> spreads,
  }) = _SpreadsState;
}

@riverpod
class Spreads extends _$Spreads {
  @override
  Future<SpreadsState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    final readerNavigation = ref.read(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );
    final spreads = [
      [0],
      ...List.generate(
        readerNavigation.totalPages ~/ 2,
        (index) => [index * 2 + 1, index * 2 + 2],
      ),
    ];
    return SpreadsState(spreads: spreads);
  }
}

@freezed
sealed class ImageSpreadsNavigationState with _$ImageSpreadsNavigationState {
  const factory ImageSpreadsNavigationState({
    required int currentSpread,
  }) = _ImageSpreadsNavigationState;
}

@riverpod
class ImageSpreadsReaderNavigation extends _$ImageSpreadsReaderNavigation {
  ReaderProvider get _readerProvider => readerProvider(
    seriesId: seriesId,
    chapterId: chapterId,
  );
  ReaderNavigationProvider get _readerNavigationProvider =>
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      );

  @override
  Future<ImageSpreadsNavigationState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    ref.listen(_readerNavigationProvider, (prev, next) async {
      final current = await future;

      final targetSpread = await _getSpreadForPage(next.currentPage);

      state = AsyncData(
        current.copyWith(currentSpread: targetSpread),
      );
    });

    final reader = await ref.read(
      _readerProvider.future,
    );

    return ImageSpreadsNavigationState(
      currentSpread: reader.initialPage ~/ 2,
    );
  }

  Future<void> nextPage() async {
    final current = await future;
    final settings = await ref.read(
      imageReaderSettingsProvider(seriesId: seriesId).future,
    );

    final nextSpread = settings.readDirection == .leftToRight
        ? current.currentSpread + 1
        : current.currentSpread - 1;

    await jumpToSpread(nextSpread);
  }

  Future<void> previousPage() async {
    final current = await future;
    final settings = await ref.read(
      imageReaderSettingsProvider(seriesId: seriesId).future,
    );

    final nextSpread = settings.readDirection == .leftToRight
        ? current.currentSpread - 1
        : current.currentSpread + 1;

    await jumpToSpread(nextSpread);
  }

  Future<int> _getSpreadForPage(int page) async {
    final spreadsState = await ref.read(
      spreadsProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    final targetSpread = spreadsState.spreads.indexWhere(
      (spread) => spread.contains(page),
    );

    return targetSpread.clamp(0, spreadsState.spreads.length - 1);
  }

  Future<void> jumpToPage(int page) async {
    final targetSpread = await _getSpreadForPage(page);
    await jumpToSpread(targetSpread);
  }

  Future<void> jumpToSpread(int spread) async {
    final spreadsState = await ref.read(
      spreadsProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    if (spread < 0 || spread >= spreadsState.spreads.length) return;

    final spreadPages = spreadsState.spreads[spread].first;
    ref.read(_readerNavigationProvider.notifier).jumpToPage(spreadPages);
    await ref
        .read(_readerProvider.notifier)
        .saveProgress(page: spreadsState.spreads[spread].last);
  }
}
