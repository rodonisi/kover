import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_navigation.freezed.dart';
part 'reader_navigation.g.dart';

@freezed
sealed class ReaderNavigationState with _$ReaderNavigationState {
  const factory ReaderNavigationState({
    required int currentPage,
    required int totalPages,
    required bool fromObserver,
  }) = _ReaderNavigationState;
}

@riverpod
class ReaderNavigation extends _$ReaderNavigation {
  bool _jumping = false;
  @override
  Future<ReaderNavigationState> build({
    required int seriesId,
    int? chapterId,
  }) async {
    // Initialize from reader state's last saved page
    final readerState = await ref.watch(
      readerProvider(seriesId: seriesId, chapterId: chapterId).future,
    );

    listenSelf((prev, next) {
      next.whenData((next) async {
        if (prev == null ||
            !prev.hasValue ||
            prev.value?.currentPage == next.currentPage) {
          return;
        }

        await saveProgress(next.currentPage);
      });
    });

    return ReaderNavigationState(
      currentPage: readerState.initialPage,
      totalPages: readerState.totalPages,
      fromObserver: false,
    );
  }

  Future<void> jumpToPage(int page, {bool fromObserver = false}) async {
    final current = await future;

    if (!fromObserver) {
      _jumping = true;
    } else if (fromObserver && page == current.currentPage) {
      _jumping = false;
    }

    if (fromObserver && _jumping) return;

    state = AsyncData(
      current.copyWith(
        currentPage: page.clamp(0, current.totalPages - 1),
        fromObserver: fromObserver,
      ),
    );
  }

  Future<void> saveProgress(int page) async {
    await ref
        .read(
          readerProvider(
            seriesId: seriesId,
            chapterId: chapterId,
          ).notifier,
        )
        .saveProgress(page: page);
  }

  Future<void> nextPage() async {
    final current = await future;

    return jumpToPage(current.currentPage + 1);
  }

  Future<void> previousPage() async {
    final current = await future;

    return jumpToPage(current.currentPage - 1);
  }
}
