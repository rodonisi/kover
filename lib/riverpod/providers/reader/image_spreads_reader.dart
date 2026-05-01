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
    required Set<int> checkedPages,
  }) = _SpreadsState;
}

@riverpod
class Spreads extends _$Spreads {
  @override
  Future<SpreadsState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    final reader = await ref.read(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ).future,
    );
    final spreads = [
      [0],
      ..._generateSpreads(1, reader.totalPages),
    ];

    return SpreadsState(spreads: spreads, checkedPages: {});
  }

  // Mark a page as landscape, putting it in its own spread respread the remainder pages
  Future<void> markLandscape(int page) async {
    final current = await future;

    final readerNavigation = ref.read(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );

    final targetSpreadIndex = current.spreads.indexWhere(
      (spread) => spread.contains(page),
    );

    if (targetSpreadIndex == -1) return;

    final targetSpread = current.spreads[targetSpreadIndex];
    if (targetSpread.length == 1) return;

    final isFirstPage = targetSpread.first == page;

    final previousSpreads = current.spreads.take(targetSpreadIndex);

    final remainingSpreads = _generateSpreads(
      page + 1,
      readerNavigation.totalPages,
    );

    final newSpreads = [
      ...previousSpreads,
      if (!isFirstPage) [targetSpread.first],
      [page],
      ...remainingSpreads,
    ];

    state = AsyncData(
      current.copyWith(
        spreads: newSpreads,
      ),
    );
  }

  Future<void> markRendered(int page) async {
    final current = await future;

    if (current.checkedPages.contains(page)) return;

    final newCheckedPages = {...current.checkedPages, page};

    state = AsyncData(
      current.copyWith(checkedPages: newCheckedPages),
    );
  }

  static List<List<int>> _generateSpreads(int startIndex, int totalPages) {
    final spreads = <List<int>>[];
    for (int i = startIndex; i < totalPages; i += 2) {
      spreads.add([i, i + 1].where((page) => page < totalPages).toList());
    }
    return spreads;
  }
}

@freezed
sealed class ImageSpreadsNavigationState with _$ImageSpreadsNavigationState {
  const factory ImageSpreadsNavigationState({
    required int currentSpread,
    required bool ready,
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
      final ready = await _isReadyForPage(next.currentPage);

      state = AsyncData(
        current.copyWith(currentSpread: targetSpread, ready: ready),
      );
    });

    ref.listen(spreadsProvider(seriesId: seriesId, chapterId: chapterId), (
      prev,
      next,
    ) {
      next.whenData((spreadsState) {
        final current = state.value;
        if (current == null) return;

        final readerNavigation = ref.read(
          readerNavigationProvider(
            seriesId: seriesId,
            chapterId: chapterId,
          ),
        );

        final targetSpread = spreadsState.spreads.indexWhere(
          (spread) => spread.contains(readerNavigation.currentPage),
        );

        if (targetSpread == -1) return;

        state = AsyncData(
          current.copyWith(
            currentSpread: targetSpread,
            ready: _containsAllPrevious(
              set: spreadsState.checkedPages,
              page: readerNavigation.currentPage,
            ),
          ),
        );
      });
    });

    final reader = await ref.read(_readerProvider.future);

    final initialSpread = await _getSpreadForPage(reader.initialPage);
    final ready = await _isReadyForPage(reader.initialPage);

    return ImageSpreadsNavigationState(
      currentSpread: initialSpread,
      ready: ready,
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

  Future<void> jumpToPage(int page) async {
    final targetSpread = await _getSpreadForPage(page);
    await jumpToSpread(targetSpread);
  }

  Future<void> jumpToSpread(int spread) async {
    final spreadsState = await ref.read(
      spreadsProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    if (spread < 0 || spread >= spreadsState.spreads.length) {
      return;
    }

    final spreadPage = spreadsState.spreads[spread].first;
    ref.read(_readerNavigationProvider.notifier).jumpToPage(spreadPage);
    await ref
        .read(_readerProvider.notifier)
        .saveProgress(page: spreadsState.spreads[spread].last);
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

  Future<bool> _isReadyForPage(int page) async {
    final spreadsState = await ref.read(
      spreadsProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    return _containsAllPrevious(set: spreadsState.checkedPages, page: page);
  }

  static bool _containsAllPrevious({required Set<int> set, required int page}) {
    for (int i = 0; i < page; i++) {
      if (!set.contains(i)) return false;
    }
    return true;
  }
}
