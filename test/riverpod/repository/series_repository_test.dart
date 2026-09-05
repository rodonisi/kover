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
    when(mockSeriesSyncOperations.getSeriesDetail(any)).thenAnswer(
      (inv) async => SeriesDetailCompanions(
        seriesId: inv.positionalArguments.first as int,
        storyline: const [],
        specials: const [],
        chapters: const [],
        volumes: const [],
      ),
    );
  });

  group('series sync', () {
    test('upserts fetched series and removes series not on server', () async {
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
        SeriesData(
          id: 2,
          libraryId: 1,
          name: 'name2',
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

      verify(mockSeriesDao.reconcileSeriesBatch(any)).called(1);
      verifyNever(mockSeriesSyncOperations.getSeriesDetail(any));
    });

    test('fetches details for ids returned by the outdated query', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      when(mockSeriesDao.getOutdatedDetailsSeriesIds()).thenAnswer(
        (_) async => [1, 2],
      );

      await repo.refreshOutdatedDetails();

      verify(mockSeriesSyncOperations.getSeriesDetail(1)).called(1);
      verify(mockSeriesSyncOperations.getSeriesDetail(2)).called(1);
      verify(mockSeriesDao.upsertDetailsBatch(any)).called(1);
    });

    test('does not fetch details when no outdated ids', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      when(mockSeriesDao.getOutdatedDetailsSeriesIds()).thenAnswer(
        (_) async => [],
      );

      await repo.refreshOutdatedDetails();

      verifyNever(mockSeriesSyncOperations.getSeriesDetail(any));
      verifyNever(mockSeriesDao.upsertDetailsBatch(any));
    });
  });

  group('on deck sync', () {
    SeriesData onDeckSeries(DateTime now) {
      return SeriesData(
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
      );
    }

    test(
      'when remote not on deck and no dirty progress, removal is added',
      () async {
        final repo = SeriesRepository(
          db: mockAppDatabase,
          client: mockSeriesSyncOperations,
          volumeClient: mockVolumeSyncOperations,
          chapterClient: mockChapterSyncOperations,
        );

        final now = DateTime.now();

        when(mockSeriesSyncOperations.getOnDeck()).thenAnswer((_) async => []);
        when(
          mockSeriesDao.getOnDeck(),
        ).thenAnswer((_) async => [onDeckSeries(now)]);
        when(
          mockSeriesDao.getDirtyOnDeckRemovalSeriesIds(),
        ).thenAnswer((_) async => []);

        await repo.syncOnDeck();

        final captured = verify(
          mockSeriesDao.upsertOnDeckRemovalBatch(captureAny),
        ).captured;

        final removals = captured.single;
        expect(removals, hasLength(1));
        final removal = removals.single as OnDeckRemovalCompanion;
        expect(removal.seriesId.value, equals(1));
        expect(removal.dirty.present, isFalse);
      },
    );

    test(
      'when remote on deck and dirty removal is outdated, removal is cleared',
      () async {
        final repo = SeriesRepository(
          db: mockAppDatabase,
          client: mockSeriesSyncOperations,
          volumeClient: mockVolumeSyncOperations,
          chapterClient: mockChapterSyncOperations,
        );

        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        when(mockSeriesSyncOperations.getOnDeck()).thenAnswer(
          (_) async => [
            SeriesCompanion(
              id: const Value(1),
              libraryId: const Value(1),
              name: const Value('name'),
              format: const Value(.epub),
              created: Value(now),
              lastChapterAdded: Value(now),
              remoteLastRead: Value(now),
            ),
          ],
        );
        when(
          mockSeriesDao.getOnDeck(),
        ).thenAnswer((_) async => [onDeckSeries(now)]);
        when(mockSeriesDao.getDirtyOnDeckRemovalSeriesIds()).thenAnswer(
          (_) async => [
            OnDeckRemovalData(
              seriesId: 1,
              dirty: true,
              created: yesterday,
            ),
          ],
        );

        await repo.syncOnDeck();

        verify(
          mockSeriesDao.clearOnDeckRemovalForSeriesBatch({
            1,
          }, cleanOnly: anyNamed('cleanOnly')),
        ).called(1);
        verifyNever(
          mockSeriesSyncOperations.removeFromOnDeck(
            seriesId: anyNamed('seriesId'),
          ),
        );
      },
    );

    test('when dirty removal is not outdated, removal is pushed', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      when(mockSeriesSyncOperations.getOnDeck()).thenAnswer((_) async => []);
      when(
        mockSeriesDao.getOnDeck(),
      ).thenAnswer((_) async => [onDeckSeries(now)]);
      when(mockSeriesDao.getDirtyOnDeckRemovalSeriesIds()).thenAnswer(
        (_) async => [
          OnDeckRemovalData(
            seriesId: 1,
            dirty: true,
            created: yesterday,
          ),
        ],
      );
      when(
        mockSeriesSyncOperations.removeFromOnDeck(seriesId: 1),
      ).thenAnswer((_) async => true);

      await repo.syncOnDeck();

      verify(mockSeriesSyncOperations.removeFromOnDeck(seriesId: 1)).called(1);
      verify(mockSeriesDao.clearDirtyOnDeckRemovalForSeries({1})).called(1);
      verifyNever(mockSeriesDao.clearOnDeckRemovalForSeriesBatch(any));
    });

    test('when push fails, dirty removal is not cleared', () async {
      final repo = SeriesRepository(
        db: mockAppDatabase,
        client: mockSeriesSyncOperations,
        volumeClient: mockVolumeSyncOperations,
        chapterClient: mockChapterSyncOperations,
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      when(mockSeriesSyncOperations.getOnDeck()).thenAnswer((_) async => []);
      when(
        mockSeriesDao.getOnDeck(),
      ).thenAnswer((_) async => [onDeckSeries(now)]);
      when(mockSeriesDao.getDirtyOnDeckRemovalSeriesIds()).thenAnswer(
        (_) async => [
          OnDeckRemovalData(
            seriesId: 1,
            dirty: true,
            created: yesterday,
          ),
        ],
      );
      when(
        mockSeriesSyncOperations.removeFromOnDeck(seriesId: 1),
      ).thenAnswer((_) async => false);

      await repo.syncOnDeck();

      verify(mockSeriesSyncOperations.removeFromOnDeck(seriesId: 1)).called(1);
      verifyNever(mockSeriesDao.clearDirtyOnDeckRemovalForSeries(any));
    });
  });
}
