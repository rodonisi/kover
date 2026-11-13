import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/progress_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:mockito/mockito.dart';

const _series = SeriesModel(
  id: 1,
  libraryId: 1,
  name: 'Series',
  format: Format.image,
  pages: 3,
  avgHoursToRead: 0,
  wordCount: null,
  primaryColor: null,
  secondaryColor: null,
  lastSynced: null,
);

const _chapter = ChapterModel(
  id: 2,
  seriesId: 1,
  volumeId: 1,
  title: 'Chapter',
  pages: 3,
);

class _FakeReaderRepository extends Mock implements ReaderRepository {
  final saves = <ProgressModel>[];

  @override
  Future<void> saveProgress(ProgressModel progress) async {
    saves.add(progress);
  }
}

void main() {
  test('does not persist the position a chapter was opened at', () async {
    final repository = _FakeReaderRepository();

    final container = ProviderContainer.test(
      overrides: [
        readerSeriesProvider(
          seriesId: 1,
        ).overrideWith((ref) async => _series),
        readerChapterProvider(
          seriesId: 1,
          chapterId: 2,
        ).overrideWith((ref) async => _chapter),
        readerProgressProvider(
          seriesId: 1,
          chapterId: 2,
        ).overrideWith((ref) async => null),
        readerRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final provider = readerProvider(
      seriesId: 1,
      chapterId: 2,
      readingListId: null,
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(provider.notifier);
    await container.read(provider.future);

    await notifier.saveProgress(page: 0);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(repository.saves, isEmpty);

    await notifier.saveProgress(page: 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(repository.saves.single.pageNum, 1);
  });
}
