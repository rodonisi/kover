import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/repository/want_to_read_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'want_to_read.g.dart';

/// Notifier that exposes want-to-read status for a series and provides
/// [add] / [remove] mutations. Delegates to [WantToReadRepository] which
/// applies optimistic writes and rolls back on failure.
@riverpod
class WantToRead extends _$WantToRead {
  @override
  Stream<bool> build({required int seriesId}) {
    final repo = ref.watch(wantToReadRepositoryProvider);
    return repo.watchWantToRead(seriesId).distinct();
  }

  Future<void> add() async {
    final repo = ref.read(wantToReadRepositoryProvider);
    await repo.add(seriesId);
  }

  Future<void> remove() async {
    final repo = ref.read(wantToReadRepositoryProvider);
    await repo.remove(seriesId);
  }
}

@riverpod
Stream<List<SeriesModel>> wantToReadList(Ref ref) {
  final repo = ref.watch(wantToReadRepositoryProvider);
  return repo.watchWantToReadList().distinct();
}
