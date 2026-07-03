import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/sync/series_sync_operations.dart';
import 'package:kover/sync/volume_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:kover/database/app_database.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<SeriesDao>(),
  MockSpec<MultiSelectable<SeriesData>>(),
  MockSpec<SeriesSyncOperations>(),
  MockSpec<ChapterSyncOperations>(),
  MockSpec<VolumeSyncOperations>(),
])
import 'series_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockAppDatabase;
  late MockSeriesDao mockSeriesDao;
  late MockSeriesSyncOperations mockSeriesSyncOperations;
  late MockVolumeSyncOperations mockVolumeSyncOperations;
  late MockChapterSyncOperations mockChapterSyncOperations;
  late MockMultiSelectable selectable;

  setUp(() {
    mockAppDatabase = MockAppDatabase();
    mockSeriesDao = MockSeriesDao();
    selectable = MockMultiSelectable();
    mockSeriesSyncOperations = MockSeriesSyncOperations();
    mockVolumeSyncOperations = MockVolumeSyncOperations();
    mockChapterSyncOperations = MockChapterSyncOperations();

    when(mockAppDatabase.seriesDao).thenReturn(mockSeriesDao);
    when(mockSeriesDao.allSeries()).thenReturn(selectable);
  });

  group('series sync', () {
    test('fetches details when series not present', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final entries = [
        SeriesCompanion(
          id: const Value(1),
          libraryId: const Value(1),
          name: const Value('name'),
          format: const Value(.epub),
          created: Value(DateTime.now()),
          lastChapterAdded: Value(DateTime.now()),
        ),
      ];

      when(mockSeriesSyncOperations.getAllSeries()).thenAnswer(
        (_) async => entries,
      );

      when(selectable.get()).thenAnswer((_) async => []);

      await repo.refreshAllSeries();

      verify(mockSeriesSyncOperations.getSeriesDetail(any)).called(1);
      verify(mockSeriesDao.mergeSeriesDetails(any)).called(1);
    });

    test('fetches detail when new chapter added', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final entries = [
        SeriesCompanion(
          id: const Value(1),
          libraryId: const Value(1),
          name: const Value('name'),
          format: const Value(.epub),
          created: Value(now),
          lastChapterAdded: Value(now),
        ),
      ];

      final existingRows = [
        SeriesData(
          id: 1,
          libraryId: 1,
          name: 'name',
          format: .epub,
          pages: 0,
          wordCount: 0,
          isBlacklisted: false,
          isRecentlyAdded: false,
          isRecentlyUpdated: false,
          created: yesterday,
          lastChapterAdded: yesterday,
          lastSynced: yesterday,
        ),
      ];

      when(mockSeriesSyncOperations.getAllSeries()).thenAnswer(
        (_) async => entries,
      );

      when(selectable.get()).thenAnswer((_) async => existingRows);

      await repo.refreshAllSeries();

      verify(mockSeriesSyncOperations.getSeriesDetail(any)).called(1);
      verify(mockSeriesDao.mergeSeriesDetails(any)).called(1);
    });

    test('fetches details when last read is newer', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final entries = [
        SeriesCompanion(
          id: const Value(1),
          libraryId: const Value(1),
          name: const Value('name'),
          format: const Value(.epub),
          created: Value(yesterday),
          lastChapterAdded: Value(yesterday),
          remoteLastRead: Value(now),
        ),
      ];
      final existingRows = [
        SeriesData(
          id: 1,
          libraryId: 1,
          name: 'name',
          format: .epub,
          pages: 0,
          wordCount: 0,
          isBlacklisted: false,
          isRecentlyAdded: false,
          isRecentlyUpdated: false,
          created: yesterday,
          lastChapterAdded: yesterday,
          lastSynced: yesterday,
        ),
      ];

      when(mockSeriesSyncOperations.getAllSeries()).thenAnswer(
        (_) async => entries,
      );

      when(selectable.get()).thenAnswer((_) async => existingRows);

      await repo.refreshAllSeries();

      verify(mockSeriesSyncOperations.getSeriesDetail(any)).called(1);
      verify(mockSeriesDao.mergeSeriesDetails(any)).called(1);
    });

    test('does not fetch details when no updates', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final now = DateTime.now();

      final entries = [
        SeriesCompanion(
          id: const Value(1),
          libraryId: const Value(1),
          name: const Value('name'),
          format: const Value(.epub),
          created: Value(now),
          lastChapterAdded: Value(now),
          remoteLastRead: Value(now),
        ),
      ];

      final existingRows = [
        SeriesData(
          id: 1,
          libraryId: 1,
          name: 'name',
          format: .epub,
          pages: 0,
          wordCount: 0,
          isBlacklisted: false,
          isRecentlyAdded: false,
          isRecentlyUpdated: false,
          created: now,
          lastChapterAdded: now,
          lastSynced: now,
        ),
      ];

      when(mockSeriesSyncOperations.getAllSeries()).thenAnswer(
        (_) async => entries,
      );

      when(selectable.get()).thenAnswer((_) async => existingRows);

      await repo.refreshAllSeries();

      verifyNever(mockSeriesSyncOperations.getSeriesDetail(any));
      verifyNever(mockSeriesDao.mergeSeriesDetails(any));
    });
  });
}
