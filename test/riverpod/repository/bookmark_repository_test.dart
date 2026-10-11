import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/bookmark_dao.dart';
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

  BookmarkData storedBookmark({
    int id = 1,
    int? serverId,
    int page = 2,
    int imageOffset = 0,
    String? xPath,
    bool dirty = false,
    bool removed = false,
  }) {
    return BookmarkData(
      id: id,
      serverId: serverId,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: page,
      imageOffset: imageOffset,
      xPath: xPath,
      created: DateTime(2026),
      dirty: dirty,
      removed: removed,
    );
  }

  test('addBookmark pushes and clears dirty on success', () async {
    final stored = storedBookmark(dirty: true);
    when(mockDao.upsert(any)).thenAnswer((_) async => stored);
    when(mockClient.add(any)).thenAnswer((_) async {});

    await repo.addBookmark(seriesId: 1, volumeId: 1, chapterId: 1, page: 2);

    verify(mockDao.upsert(any)).called(1);
    verify(mockClient.add(any)).called(1);
    verify(mockDao.clearDirtyFlags([1])).called(1);
  });

  test(
    'removeBookmark hard-deletes a never-synced row without server call',
    () async {
      final stored = storedBookmark(dirty: true);
      when(
        mockDao.getBookmark(chapterId: 1, page: 2, imageOffset: 0),
      ).thenAnswer((_) async => stored);

      await repo.removeBookmark(chapterId: 1, page: 2);

      verify(mockDao.deleteByIds([1])).called(1);
      verifyNever(mockClient.remove(any));
    },
  );

  test('removeBookmark tombstones a synced row and pushes', () async {
    final stored = storedBookmark(serverId: 9);
    when(
      mockDao.getBookmark(chapterId: 1, page: 2, imageOffset: 0),
    ).thenAnswer((_) async => stored);
    when(mockClient.remove(any)).thenAnswer((_) async {});

    await repo.removeBookmark(chapterId: 1, page: 2);

    verify(mockDao.markRemoved(1)).called(1);
    verify(mockClient.remove(any)).called(1);
    verify(mockDao.deleteByIds([1])).called(1);
  });

  test('removeBookmark failed push leaves tombstone intact', () async {
    final stored = storedBookmark(serverId: 9);
    when(
      mockDao.getBookmark(chapterId: 1, page: 2, imageOffset: 0),
    ).thenAnswer((_) async => stored);
    when(mockClient.remove(any)).thenThrow(Exception('boom'));

    await repo.removeBookmark(chapterId: 1, page: 2);

    verify(mockDao.markRemoved(1)).called(1);
    verifyNever(mockDao.deleteByIds(any));
  });

  test(
    'mergeBookmarks pushes dirty adds and removes then deletes tombstones',
    () async {
      final toAdd = storedBookmark(dirty: true);
      final toRemove = storedBookmark(
        id: 2,
        serverId: 5,
        page: 3,
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
      when(mockDao.getBookmarks()).thenAnswer((_) async => []);

      await repo.refreshAllBookmarks();

      final captured = verify(mockDao.upsert(captureAny)).captured;
      expect(captured, hasLength(1));
      expect((captured.single as BookmarksCompanion).chapterId.value, 1);
    },
  );

  test('refreshAllBookmarks does not resurrect a dirty local row', () async {
    final tombstone = storedBookmark(serverId: 9, dirty: true, removed: true);
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
      mockDao.getBookmark(chapterId: 1, page: 2, imageOffset: 0),
    ).thenAnswer((_) async => tombstone);
    when(mockDao.getBookmarks()).thenAnswer((_) async => []);

    await repo.refreshAllBookmarks();

    verifyNever(mockDao.upsert(any));
  });

  test(
    'refreshAllBookmarks deletes clean local rows absent from remote',
    () async {
      final stale = storedBookmark(id: 7, serverId: 7, page: 5);
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
      when(mockDao.getBookmarks()).thenAnswer((_) async => [stale]);

      await repo.refreshAllBookmarks();

      verify(mockDao.deleteByIds([7])).called(1);
    },
  );

  test(
    'refreshAllBookmarks keeps dirty local rows absent from remote',
    () async {
      final clean = storedBookmark(id: 7, serverId: 7, page: 5);
      final dirty = storedBookmark(id: 8, page: 9, dirty: true);
      when(mockClient.getAllBookmarks()).thenAnswer((_) async => []);
      when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
      when(mockDao.getBookmarks()).thenAnswer((_) async => [clean, dirty]);

      await repo.refreshAllBookmarks();

      verify(mockDao.deleteByIds([7])).called(1);
      verifyNever(mockDao.deleteByIds(argThat(contains(8))));
    },
  );

  test(
    'refreshAllBookmarks matches remote by xPath',
    () async {
      final epub = storedBookmark(id: 7, serverId: 7, page: 5, xPath: '/p[1]');
      final image = storedBookmark(id: 8, serverId: 8, page: 5);
      when(mockClient.getAllBookmarks()).thenAnswer(
        (_) async => [
          const BookmarkDto(
            id: 7,
            page: 5,
            volumeId: 1,
            seriesId: 1,
            chapterId: 1,
            xPath: '/p[1]',
          ),
        ],
      );
      when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
      when(mockDao.getBookmarks()).thenAnswer((_) async => [epub, image]);

      await repo.refreshAllBookmarks();

      verify(mockDao.deleteByIds([8])).called(1);
      verifyNever(mockDao.deleteByIds(argThat(contains(7))));
    },
  );

  test('watchBookmarks maps rows and forwards the scope', () async {
    when(
      mockDao.watchBookmarks(seriesId: 1, volumeId: 2, chapterId: null),
    ).thenAnswer(
      (_) => Stream.value([storedBookmark(id: 3, page: 4)]),
    );

    final list = await repo.watchBookmarks(seriesId: 1, volumeId: 2).first;

    expect(list, hasLength(1));
    expect(list.single.id, 3);
    expect(list.single.page, 4);
    verify(
      mockDao.watchBookmarks(seriesId: 1, volumeId: 2, chapterId: null),
    ).called(1);
  });
}
