import 'package:freezed_annotation/freezed_annotation.dart';
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
  @override
  Future<VerticalReaderCacheState> build({
    required int seriesId,
    required int chapterId,
  }) async {
    return const VerticalReaderCacheState(cachedHeights: {});
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
