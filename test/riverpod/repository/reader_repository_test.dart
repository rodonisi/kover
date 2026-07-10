import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/reader_dao.dart';
import 'package:kover/riverpod/repository/reader_repository.dart';
import 'package:kover/sync/reader_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<ReaderDao>(),
  MockSpec<ReaderSyncOperations>(),
])
import 'reader_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockReaderDao mockReaderDao;
  late MockReaderSyncOperations mockReaderClient;

  setUp(() {
    mockDb = MockAppDatabase();
    mockReaderDao = MockReaderDao();
    mockReaderClient = MockReaderSyncOperations();

    when(mockDb.readerDao).thenReturn(mockReaderDao);
  });

  group('progress sync', () {
    test('fetches when newer progress', () async {
      final repo = ReaderRepository(
        db: mockDb,
        readerClient: mockReaderClient,
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final expected = ReadingProgressCompanion(
        chapterId: const Value(1),
        volumeId: const Value(1),
        seriesId: const Value(1),
        libraryId: const Value(1),
        pagesRead: const Value(10),
        bookScrollId: const Value('scrollId'),
        totalReads: const Value(1),
        created: Value(yesterday),
        lastModified: Value(now),
      );

      when(
        mockReaderDao.getOutdatedChapterIds(),
      ).thenAnswer((_) async => [1]);
      when(mockReaderClient.getProgress(1)).thenAnswer((_) async => expected);

      await repo.refreshOutdatedProgress();

      verify(mockReaderDao.mergeProgressBatch([expected])).called(1);
    });
  });
}

class ReaderProgressCompanion {}
