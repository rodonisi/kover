import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/annotation_dao.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<AnnotationDao>(),
  MockSpec<AnnotationSyncOperations>(),
])
import 'annotation_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockAnnotationDao mockDao;
  late MockAnnotationSyncOperations mockClient;
  late AnnotationRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockDao = MockAnnotationDao();
    mockClient = MockAnnotationSyncOperations();
    when(mockDb.annotationDao).thenReturn(mockDao);
    repo = AnnotationRepository(mockDb, mockClient);
  });

  Annotation storedAnnotation({
    int id = 1,
    int? serverId,
    int chapterId = 1,
    bool dirty = false,
    bool removed = false,
  }) {
    return Annotation(
      id: id,
      serverId: serverId,
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      libraryId: 1,
      ownerUserId: 1,
      xPath: '/p[1]',
      selectedText: 'text',
      likes: const [],
      created: DateTime(2026),
      dirty: dirty,
      removed: removed,
    );
  }

  AnnotationDto remoteAnnotation({int id = 9, int chapterId = 1}) {
    return AnnotationDto(
      id: id,
      xPath: '/p[1]',
      selectedText: 'text',
      chapterId: chapterId,
      volumeId: 1,
      seriesId: 1,
      libraryId: 1,
      ownerUserId: 1,
    );
  }

  test('addAnnotation pushes a create and stores the server row', () async {
    final stored = storedAnnotation(dirty: true);
    when(mockDao.upsert(any)).thenAnswer((_) async => stored);
    when(mockClient.create(any)).thenAnswer((_) async => remoteAnnotation());

    await repo.addAnnotation(
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      libraryId: 1,
      ownerUserId: 1,
      xPath: '/p[1]',
      selectedText: 'text',
    );

    verify(mockClient.create(any)).called(1);
    final captured = verify(mockDao.upsert(captureAny)).captured;
    expect(captured, hasLength(2));
    final merged = captured.last as AnnotationsCompanion;
    expect(merged.serverId.value, 9);
    expect(merged.dirty.value, isFalse);
    expect(merged.removed.value, isFalse);
  });

  test('addAnnotation keeps the row dirty when push fails', () async {
    when(mockDao.upsert(any)).thenAnswer(
      (_) async => storedAnnotation(dirty: true),
    );
    when(mockClient.create(any)).thenThrow(Exception('offline'));

    await repo.addAnnotation(
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      libraryId: 1,
      ownerUserId: 1,
      selectedText: 'text',
    );

    verify(mockDao.upsert(any)).called(1);
  });

  test('removeAnnotation hard-deletes a never-synced row', () async {
    when(mockDao.getAnnotation(1)).thenAnswer(
      (_) async => storedAnnotation(dirty: true),
    );

    await repo.removeAnnotation(1);

    verify(mockDao.deleteByIds([1])).called(1);
    verifyNever(mockClient.remove(any));
  });

  test('removeAnnotation tombstones a synced row and pushes', () async {
    when(mockDao.getAnnotation(1)).thenAnswer(
      (_) async => storedAnnotation(serverId: 9),
    );
    when(mockClient.remove(any)).thenAnswer((_) async {});

    await repo.removeAnnotation(1);

    verify(mockDao.markRemoved(1)).called(1);
    verify(mockClient.remove(9)).called(1);
    verify(mockDao.deleteByIds([1])).called(1);
  });

  test('mergeAnnotations creates, updates and deletes dirty rows', () async {
    final create = storedAnnotation(id: 1, dirty: true);
    final update = storedAnnotation(id: 2, serverId: 5, dirty: true);
    final remove = storedAnnotation(
      id: 3,
      serverId: 6,
      dirty: true,
      removed: true,
    );
    when(mockDao.getDirtyAnnotations()).thenAnswer(
      (_) async => [create, update, remove],
    );
    when(mockDao.upsert(any)).thenAnswer((_) async => create);
    when(mockClient.create(any)).thenAnswer(
      (_) async => remoteAnnotation(id: 10),
    );
    when(mockClient.update(any)).thenAnswer(
      (_) async => remoteAnnotation(id: 5),
    );
    when(mockClient.remove(any)).thenAnswer((_) async {});

    await repo.mergeAnnotations();

    verify(mockClient.create(any)).called(1);
    verify(mockClient.update(any)).called(1);
    verify(mockClient.remove(6)).called(1);
    verify(mockDao.deleteByIds([3])).called(1);
  });

  test('refreshAllAnnotations skips remote rows dirty locally', () async {
    final dirty = storedAnnotation(serverId: 9, dirty: true);
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [remoteAnnotation()],
    );
    when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
    when(mockDao.getAnnotationByServerId(9)).thenAnswer((_) async => dirty);
    when(mockDao.getAnnotations()).thenAnswer((_) async => [dirty]);

    await repo.refreshAllAnnotations();

    verifyNever(mockDao.upsert(any));
    verifyNever(mockDao.deleteByIds(any));
  });

  test('refreshAllAnnotations deletes clean rows absent remotely', () async {
    final clean = storedAnnotation(id: 7, serverId: 7);
    final dirty = storedAnnotation(id: 8, serverId: 8, dirty: true);
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [remoteAnnotation(id: 1)],
    );
    when(mockDao.getExistingChapterIds()).thenAnswer((_) async => [1]);
    when(mockDao.getAnnotationByServerId(1)).thenAnswer((_) async => null);
    when(mockDao.getAnnotations()).thenAnswer((_) async => [clean, dirty]);

    await repo.refreshAllAnnotations();

    verify(mockDao.upsert(any)).called(1);
    verify(mockDao.deleteByIds([7])).called(1);
    verifyNever(mockDao.deleteByIds(argThat(contains(8))));
  });

  test(
    'refreshChapterAnnotations scopes reconciliation to the chapter',
    () async {
      final stale = storedAnnotation(id: 7, serverId: 7, chapterId: 2);
      when(mockClient.getChapterAnnotations(2)).thenAnswer((_) async => []);
      when(mockDao.getAnnotationsForChapter(2)).thenAnswer(
        (_) async => [stale],
      );

      await repo.refreshChapterAnnotations(chapterId: 2);

      verify(mockClient.getChapterAnnotations(2)).called(1);
      verify(mockDao.deleteByIds([7])).called(1);
    },
  );
}
