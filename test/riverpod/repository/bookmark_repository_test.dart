import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart'
    hide AgeRating, PublicationStatus;
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/bookmark_dao.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/riverpod/repository/bookmark_repository.dart';
import 'package:kover/sync/bookmark_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<BookmarkDao>(),
  MockSpec<BookmarkSyncOperations>(),
])
import 'bookmark_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockBookmarkDao mockDao;
  late MockBookmarkSyncOperations mockClient;
  late BookmarkRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockDao = MockBookmarkDao();
    mockClient = MockBookmarkSyncOperations();
    when(mockDb.bookmarkDao).thenReturn(mockDao);
    repo = BookmarkRepository(mockDb, mockClient);
  });

  test('addBookmark pushes and clears dirty on success', () async {
    final stored = BookmarkData(
      id: 1,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 2,
      imageOffset: -1,
      xPath: '',
      created: DateTime(2026),
      dirty: true,
      removed: false,
    );
    when(mockDao.upsertByNaturalKey(any)).thenAnswer((_) async => stored);
    when(mockClient.add(any)).thenAnswer((_) async {});

    await repo.addBookmark(seriesId: 1, volumeId: 1, chapterId: 1, page: 2);

    verify(mockDao.upsertByNaturalKey(any)).called(1);
    verify(mockClient.add(any)).called(1);
    verify(mockDao.clearDirtyFlags([1])).called(1);
  });

  test(
    'removeBookmark hard-deletes a never-synced row without server call',
    () async {
      final stored = BookmarkData(
        id: 1,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: true,
        removed: false,
      );
      when(
        mockDao.getByLocation(chapterId: 1, page: 2, imageOffset: -1),
      ).thenAnswer((_) async => stored);

      await repo.removeBookmark(chapterId: 1, page: 2);

      verify(mockDao.deleteByIds([1])).called(1);
      verifyNever(mockClient.remove(any));
    },
  );

  test('removeBookmark tombstones a synced row and pushes', () async {
    final stored = BookmarkData(
      id: 1,
      serverId: 9,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 2,
      imageOffset: -1,
      xPath: '',
      created: DateTime(2026),
      dirty: false,
      removed: false,
    );
    when(
      mockDao.getByLocation(
        chapterId: 1,
        page: 2,
        imageOffset: -1,
      ),
    ).thenAnswer((_) async => stored);
    when(mockClient.remove(any)).thenAnswer((_) async {});

    await repo.removeBookmark(chapterId: 1, page: 2);

    verify(mockDao.markRemoved(1)).called(1);
    verify(mockClient.remove(any)).called(1);
    verify(mockDao.deleteByIds([1])).called(1);
  });

  test(
    're-add after pending removal reuses the row and pushes an add',
    () async {
      final tombstone = BookmarkData(
        id: 1,
        serverId: 9,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: true,
        removed: true,
      );
      when(
        mockDao.getByLocation(
          chapterId: 1,
          page: 2,
          imageOffset: -1,
        ),
      ).thenAnswer((_) async => tombstone);
      final reused = tombstone.copyWith(dirty: true, removed: false);
      when(mockDao.updateById(1, any)).thenAnswer((_) async => reused);
      when(mockClient.add(any)).thenAnswer((_) async {});

      await repo.addBookmark(seriesId: 1, volumeId: 1, chapterId: 1, page: 2);

      verify(mockDao.updateById(1, any)).called(1);
      verifyNever(mockDao.upsertByNaturalKey(any));
      verify(mockClient.add(any)).called(1);
      verifyNever(mockClient.remove(any));
    },
  );

  test(
    'mergeBookmarks pushes dirty adds and removes then deletes tombstones',
    () async {
      final toAdd = BookmarkData(
        id: 1,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: true,
        removed: false,
      );
      final toRemove = BookmarkData(
        id: 2,
        serverId: 5,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 3,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: true,
        removed: true,
      );
      when(mockDao.getDirtyBookmarks())
          .thenAnswer((_) async => [toAdd, toRemove]);
      when(mockClient.add(any)).thenAnswer((_) async {});
      when(mockClient.remove(any)).thenAnswer((_) async {});

      await repo.mergeBookmarks();

      verify(mockClient.add(any)).called(1);
      verify(mockClient.remove(any)).called(1);
      verify(mockDao.deleteByIds([2])).called(1);
      verify(mockDao.clearDirtyFlags([1])).called(1);
    },
  );

  test(
    'refreshAllBookmarks skips bookmarks for chapters not stored locally',
    () async {
      when(mockClient.getAllBookmarks()).thenAnswer(
        (_) async => [
          const BookmarkDto(
            id: 1,
            page: 0,
            volumeId: 1,
            seriesId: 1,
            chapterId: 1,
          ),
          const BookmarkDto(
            id: 2,
            page: 0,
            volumeId: 2,
            seriesId: 2,
            chapterId: 99,
          ),
        ],
      );
      when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);

      await repo.refreshAllBookmarks();

      final captured = verify(mockDao.upsertByNaturalKey(captureAny)).captured;
      expect(captured, hasLength(1));
      expect((captured.single as BookmarksCompanion).chapterId.value, 1);
    },
  );

  test('refreshAllBookmarks does not resurrect a dirty local row', () async {
    final tombstone = BookmarkData(
      id: 1,
      serverId: 9,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 2,
      imageOffset: -1,
      xPath: '',
      created: DateTime(2026),
      dirty: true,
      removed: true,
    );
    when(mockClient.getAllBookmarks()).thenAnswer(
      (_) async => [
        const BookmarkDto(
          id: 1,
          page: 2,
          volumeId: 1,
          seriesId: 1,
          chapterId: 1,
        ),
      ],
    );
    when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
    when(
      mockDao.getByLocation(
        chapterId: 1,
        page: 2,
        imageOffset: -1,
      ),
    ).thenAnswer((_) async => tombstone);

    await repo.refreshAllBookmarks();

    verifyNever(mockDao.upsertByNaturalKey(any));
  });

  test(
    'removeBookmark after successful add pushes remove then deletes',
    () async {
      final stored = BookmarkData(
        id: 1,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: false,
        removed: false,
      );
      when(
        mockDao.getByLocation(
          chapterId: 1,
          page: 2,
          imageOffset: -1,
        ),
      ).thenAnswer((_) async => stored);
      when(mockClient.remove(any)).thenAnswer((_) async {});

      await repo.removeBookmark(chapterId: 1, page: 2);

      verify(mockClient.remove(any)).called(1);
      verify(mockDao.deleteByIds([1])).called(1);
    },
  );

  test('watchBookmarkedSeries maps database rows to models', () async {
    when(mockDao.watchBookmarkedSeries()).thenAnswer(
      (_) => Stream.value([
        SeriesData(
          id: 1,
          libraryId: 1,
          name: 'S',
          format: Format.epub,
          pages: 0,
          wordCount: 0,
          isBlacklisted: false,
          isRecentlyAdded: false,
          isRecentlyUpdated: false,
          created: DateTime(2026),
        ),
      ]),
    );

    final list = await repo.watchBookmarkedSeries().first;

    expect(list, hasLength(1));
    expect(list.single.name, 'S');
  });

  test('watchBookmarkedChapters maps rows and forwards filters', () async {
    when(
      mockDao.watchBookmarkedChapters(seriesId: 1, volumeId: 2),
    ).thenAnswer(
      (_) => Stream.value([
        Chapter(
          id: 3,
          volumeId: 2,
          seriesId: 1,
          format: Format.epub,
          minNumber: 0,
          maxNumber: 0,
          sortOrder: 0,
          pages: 10,
          wordCount: 0,
          ageRating: AgeRating.unknown,
          publicationStatus: PublicationStatus.unknown,
          isSpecial: false,
          isStoryline: false,
          releaseDate: DateTime(2026),
          totalReads: 0,
          created: DateTime(2026),
          lastModified: DateTime(2026),
        ),
      ]),
    );

    final list = await repo
        .watchBookmarkedChapters(seriesId: 1, volumeId: 2)
        .first;

    expect(list, hasLength(1));
    expect(list.single.id, 3);
    verify(mockDao.watchBookmarkedChapters(seriesId: 1, volumeId: 2)).called(1);
  });

  test('removeBookmark failed push leaves tombstone intact', () async {
    final stored = BookmarkData(
      id: 1,
      serverId: 9,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 2,
      imageOffset: -1,
      xPath: '',
      created: DateTime(2026),
      dirty: false,
      removed: false,
    );
    when(
      mockDao.getByLocation(
        chapterId: 1,
        page: 2,
        imageOffset: -1,
      ),
    ).thenAnswer((_) async => stored);
    when(mockClient.remove(any)).thenThrow(Exception('boom'));

    await repo.removeBookmark(chapterId: 1, page: 2);

    verify(mockDao.markRemoved(1)).called(1);
    verifyNever(mockDao.deleteByIds(any));
  });

  test(
    'addBookmark updates the existing row in place when xPath changes',
    () async {
      final existing = BookmarkData(
        id: 5,
        serverId: 9,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: 'xpath-A',
        created: DateTime(2026),
        dirty: false,
        removed: false,
      );
      final updated = existing.copyWith(xPath: 'xpath-B', dirty: true);
      when(
        mockDao.getByLocation(chapterId: 1, page: 2, imageOffset: -1),
      ).thenAnswer((_) async => existing);
      when(mockDao.updateById(5, any)).thenAnswer((_) async => updated);
      when(mockClient.add(any)).thenAnswer((_) async {});

      await repo.addBookmark(
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        xPath: 'xpath-B',
      );

      verify(mockDao.updateById(5, any)).called(1);
      verifyNever(mockDao.upsertByNaturalKey(any));
      verify(mockClient.add(any)).called(1);
      verify(mockDao.clearDirtyFlags([5])).called(1);
    },
  );

  test(
    'removeBookmark matches by location and ignores a changed xPath',
    () async {
      final stored = BookmarkData(
        id: 1,
        serverId: 9,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 2,
        imageOffset: -1,
        xPath: 'xpath-A',
        created: DateTime(2026),
        dirty: false,
        removed: false,
      );
      when(
        mockDao.getByLocation(chapterId: 1, page: 2, imageOffset: -1),
      ).thenAnswer((_) async => stored);
      when(mockClient.remove(any)).thenAnswer((_) async {});

      // Same chapter/page/imageOffset, different (reflowed) xPath.
      await repo.removeBookmark(chapterId: 1, page: 2, xPath: 'xpath-B');

      verify(
        mockDao.getByLocation(chapterId: 1, page: 2, imageOffset: -1),
      ).called(1);
      verify(mockDao.markRemoved(1)).called(1);
      verify(mockClient.remove(any)).called(1);
      verify(mockDao.deleteByIds([1])).called(1);
    },
  );

  test(
    'refreshAllBookmarks deletes clean local rows absent from remote',
    () async {
      final stale = BookmarkData(
        id: 7,
        serverId: 7,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 5,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: false,
        removed: false,
      );
      when(mockClient.getAllBookmarks()).thenAnswer(
        (_) async => [
          const BookmarkDto(
            id: 1,
            page: 2,
            volumeId: 1,
            seriesId: 1,
            chapterId: 1,
          ),
        ],
      );
      when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
      when(mockDao.getLocalBookmarks()).thenAnswer((_) async => [stale]);

      await repo.refreshAllBookmarks();

      verify(mockDao.deleteByIds([7])).called(1);
    },
  );

  test(
    'refreshAllBookmarks keeps dirty local rows absent from remote',
    () async {
      final clean = BookmarkData(
        id: 7,
        serverId: 7,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 5,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: false,
        removed: false,
      );
      final dirty = BookmarkData(
        id: 8,
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        page: 9,
        imageOffset: -1,
        xPath: '',
        created: DateTime(2026),
        dirty: true,
        removed: false,
      );
      when(mockClient.getAllBookmarks()).thenAnswer((_) async => []);
      when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
      when(
        mockDao.getLocalBookmarks(),
      ).thenAnswer((_) async => [clean, dirty]);

      await repo.refreshAllBookmarks();

      verify(mockDao.deleteByIds([7])).called(1);
      verifyNever(mockDao.deleteByIds(argThat(contains(8))));
    },
  );
}
