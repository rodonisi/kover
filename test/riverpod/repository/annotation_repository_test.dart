import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart' hide HighlightSlot;
import 'package:kover/database/dao/annotation_dao.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<AnnotationDao>(),
  MockSpec<ChaptersDao>(),
  MockSpec<AnnotationSyncOperations>(),
])
import 'annotation_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockAnnotationDao mockDao;
  late MockChaptersDao mockChapterDao;
  late MockAnnotationSyncOperations mockClient;
  late AnnotationRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockDao = MockAnnotationDao();
    mockChapterDao = MockChaptersDao();
    mockClient = MockAnnotationSyncOperations();
    when(mockDb.annotationDao).thenReturn(mockDao);
    when(mockDb.chaptersDao).thenReturn(mockChapterDao);
    repo = AnnotationRepository(mockDb, mockClient);
  });

  Annotation storedAnnotation({
    int id = 1,
    int? serverId,
    int chapterId = 1,
    bool dirty = false,
    bool removed = false,
    DateTime? lastModified,
  }) {
    final created = DateTime.utc(2026);
    return Annotation(
      id: id,
      serverId: serverId,
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      libraryId: 1,
      ownerUserId: 1,
      xPath: '/p[1]',
      endingXPath: '/p[1]',
      selectedText: 'text',
      comment: '{}',
      containsSpoiler: false,
      pageNumber: 1,
      selectedSlotIndex: 0,
      likes: const [],
      created: created,
      lastModified: lastModified ?? created,
      dirty: dirty,
      removed: removed,
    );
  }

  AnnotationDto remoteAnnotation({
    int id = 9,
    int chapterId = 1,
    String? xPath = '/p[1]',
    String? endingXPath,
    String? selectedText = 'text',
    DateTime? createdUtc,
    DateTime? lastModifiedUtc,
  }) {
    final timestamp = DateTime.utc(2026);
    return AnnotationDto(
      id: id,
      xPath: xPath,
      endingXPath: endingXPath,
      selectedText: selectedText,
      pageNumber: 1,
      selectedSlotIndex: 0,
      chapterId: chapterId,
      volumeId: 1,
      seriesId: 1,
      libraryId: 1,
      ownerUserId: 1,
      createdUtc: createdUtc ?? timestamp,
      lastModifiedUtc: lastModifiedUtc ?? timestamp,
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
      endingXPath: '/p[1]',
      selectedText: 'text',
      comment: '{}',
      pageNumber: 1,
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
    final stored = storedAnnotation(dirty: true);
    when(mockDao.upsert(any)).thenAnswer((_) async => stored);
    when(mockDao.getAnnotation(1)).thenAnswer((_) async => stored);
    when(mockClient.create(any)).thenThrow(Exception('offline'));

    await repo.addAnnotation(
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      libraryId: 1,
      ownerUserId: 1,
      xPath: '/p[1]',
      endingXPath: '/p[1]',
      selectedText: 'text',
      comment: '{}',
      pageNumber: 1,
    );

    verify(mockDao.upsert(any)).called(1);
  });

  test(
    'addAnnotation keeps the row dirty when server returns an invalid dto',
    () async {
      final stored = storedAnnotation(dirty: true);
      when(mockDao.upsert(any)).thenAnswer((_) async => stored);
      when(mockClient.create(any)).thenAnswer(
        (_) async => remoteAnnotation(xPath: '   '),
      );

      await repo.addAnnotation(
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        libraryId: 1,
        ownerUserId: 1,
        xPath: '/p[1]',
        endingXPath: '/p[1]',
        selectedText: 'text',
        comment: '{}',
        pageNumber: 1,
      );

      verify(mockDao.upsert(any)).called(1);
    },
  );

  test('removeAnnotation tombstones and clears a never-synced row', () async {
    when(
      mockDao.markRemoved(1, ownerUserId: 1),
    ).thenAnswer(
      (_) async => storedAnnotation(dirty: true, removed: true),
    );

    await repo.removeAnnotation(1, ownerUserId: 1);

    verify(mockDao.markRemoved(1, ownerUserId: 1)).called(1);
    verifyNever(mockDao.getAnnotation(any));
    verify(mockDao.deleteByIds([1])).called(1);
    verifyNever(mockClient.remove(any));
  });

  test('removeAnnotation tombstones a synced row and pushes', () async {
    when(
      mockDao.markRemoved(1, ownerUserId: 1),
    ).thenAnswer(
      (_) async => storedAnnotation(
        serverId: 9,
        dirty: true,
        removed: true,
      ),
    );
    when(mockClient.remove(any)).thenAnswer((_) async {});

    await repo.removeAnnotation(1, ownerUserId: 1);

    verify(mockDao.markRemoved(1, ownerUserId: 1)).called(1);
    verifyNever(mockDao.getAnnotation(any));
    verify(mockClient.remove(9)).called(1);
    verify(mockDao.deleteByIds([1])).called(1);
  });

  test('updateAnnotation ignores rows owned by another user', () async {
    when(mockDao.getAnnotation(1)).thenAnswer(
      (_) async => storedAnnotation(serverId: 9),
    );

    await repo.updateAnnotation(
      id: 1,
      ownerUserId: 2,
      comment: 'hijack',
      commentHtml: '<p>hijack</p>',
      containsSpoiler: false,
      selectedSlotIndex: 0,
    );

    verifyNever(mockDao.upsert(any));
    verifyNever(mockClient.update(any));
  });

  test('removeAnnotation ignores rows owned by another user', () async {
    when(
      mockDao.markRemoved(1, ownerUserId: 2),
    ).thenAnswer((_) async => null);

    await repo.removeAnnotation(1, ownerUserId: 2);

    verify(mockDao.markRemoved(1, ownerUserId: 2)).called(1);
    verifyNever(mockDao.getAnnotation(any));
    verifyNever(mockDao.deleteByIds(any));
    verifyNever(mockClient.remove(any));
  });

  test('updateAnnotation pushes an update and marks the row clean', () async {
    final existing = storedAnnotation(serverId: 9);
    final updated = storedAnnotation(serverId: 9, dirty: true);
    when(mockDao.getAnnotation(1)).thenAnswer((_) async => existing);
    when(mockDao.upsert(any)).thenAnswer((_) async => updated);
    when(mockClient.update(any)).thenAnswer(
      (_) async => remoteAnnotation(id: 9),
    );

    await repo.updateAnnotation(
      id: 1,
      ownerUserId: 1,
      comment: 'updated',
      commentHtml: '<p>updated</p>',
      containsSpoiler: false,
      selectedSlotIndex: 0,
    );

    verify(mockClient.update(any)).called(1);
    final captured = verify(mockDao.upsert(captureAny)).captured;
    expect(captured, hasLength(2));
    final merged = captured.last as AnnotationsCompanion;
    expect(merged.dirty.value, isFalse);
  });

  test('updateAnnotation leaves the row dirty when push fails', () async {
    final existing = storedAnnotation(serverId: 9);
    final updated = storedAnnotation(serverId: 9, dirty: true);
    when(mockDao.getAnnotation(1)).thenAnswer((_) async => existing);
    when(mockDao.upsert(any)).thenAnswer((_) async => updated);
    when(mockClient.update(any)).thenThrow(Exception('offline'));

    await repo.updateAnnotation(
      id: 1,
      ownerUserId: 1,
      comment: 'updated',
      commentHtml: '<p>updated</p>',
      containsSpoiler: false,
      selectedSlotIndex: 0,
    );

    verify(mockDao.upsert(any)).called(1);
  });

  test('removeAnnotation keeps the tombstone when push fails', () async {
    when(
      mockDao.markRemoved(1, ownerUserId: 1),
    ).thenAnswer(
      (_) async => storedAnnotation(
        serverId: 9,
        dirty: true,
        removed: true,
      ),
    );
    when(mockClient.remove(9)).thenThrow(Exception('offline'));

    await repo.removeAnnotation(1, ownerUserId: 1);

    verify(mockDao.markRemoved(1, ownerUserId: 1)).called(1);
    verifyNever(mockDao.deleteByIds(any));
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
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [remoteAnnotation()],
    );
    when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {1});
    when(mockDao.mergeRemoteBatch(any)).thenAnswer((_) async {});

    await repo.refreshAllAnnotations();

    verify(mockDao.mergeRemoteBatch(any)).called(1);
    verifyNever(mockDao.upsert(any));
    verify(
      mockDao.deleteStaleAnnotations(argThat(contains(9))),
    ).called(1);
    verifyNever(mockDao.deleteByIds(any));
  });

  test('refreshAllAnnotations delegates stale deletion to the dao', () async {
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [remoteAnnotation(id: 1)],
    );
    when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {1});
    when(mockDao.mergeRemoteBatch(any)).thenAnswer((_) async {});

    await repo.refreshAllAnnotations();

    verify(mockDao.mergeRemoteBatch(any)).called(1);
    verifyNever(mockDao.upsert(any));
    verify(
      mockDao.deleteStaleAnnotations(argThat(contains(1))),
    ).called(1);
    verifyNever(mockDao.deleteByIds(any));
  });

  test('refreshAllAnnotations reconciles more than one remote page', () async {
    final remote = List.generate(
      25,
      (index) => remoteAnnotation(id: index + 1),
    );
    when(mockClient.getAllAnnotations()).thenAnswer((_) async => remote);
    when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {1});
    when(mockDao.mergeRemoteBatch(any)).thenAnswer((_) async {});

    await repo.refreshAllAnnotations();

    final remoteIds =
        verify(mockDao.deleteStaleAnnotations(captureAny)).captured.single
            as Iterable<int>;
    expect(remoteIds, unorderedEquals(List.generate(25, (index) => index + 1)));
  });

  test('refreshAllAnnotations skips unknown chapters', () async {
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [remoteAnnotation(id: 9, chapterId: 2)],
    );
    when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {1});

    await repo.refreshAllAnnotations();

    verify(mockDao.mergeRemoteBatch(argThat(isEmpty))).called(1);
    verifyNever(mockDao.upsert(any));
  });

  test('refreshAllAnnotations ignores unrenderable remote rows', () async {
    when(mockClient.getAllAnnotations()).thenAnswer(
      (_) async => [
        remoteAnnotation(id: 1, xPath: '  '),
        remoteAnnotation(id: 2, selectedText: ''),
        remoteAnnotation(id: 3),
      ],
    );
    when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {1});
    when(mockDao.mergeRemoteBatch(any)).thenAnswer((_) async {});

    await repo.refreshAllAnnotations();

    final merged =
        verify(mockDao.mergeRemoteBatch(captureAny)).captured.single
            as Iterable<AnnotationsCompanion>;
    expect(merged.map((entry) => entry.serverId.value), [3]);
    verify(mockDao.deleteStaleAnnotations({3})).called(1);
  });

  test(
    'refreshChapterAnnotations scopes reconciliation to the chapter',
    () async {
      when(mockClient.getChapterAnnotations(2)).thenAnswer((_) async => []);
      when(mockChapterDao.getExistingChapterIds()).thenAnswer((_) async => {2});

      await repo.refreshChapterAnnotations(chapterId: 2);

      verify(mockClient.getChapterAnnotations(2)).called(1);
      verify(mockDao.mergeRemoteBatch(argThat(isEmpty))).called(1);
      verify(
        mockDao.deleteStaleAnnotations(argThat(isEmpty), chapterId: 2),
      ).called(1);
      verifyNever(mockDao.deleteByIds(any));
    },
  );

  test('refreshHighlightSlots stores current account preferences', () async {
    when(mockClient.getCurrentUser()).thenAnswer(
      (_) async => const UserDto(
        preferences: UserPreferencesDto(
          theme: SiteThemeDto(),
          blurUnreadSummaries: false,
          promptForDownloadSize: false,
          noTransitions: false,
          collapseSeriesRelationships: false,
          locale: 'en',
          colorScapeEnabled: false,
          dataSaver: false,
          promptForRereadsAfter: 0,
          customKeyBinds: UserPreferencesDto$CustomKeyBinds(),
          bookReaderHighlightSlots: [HighlightSlot(slotNumber: 0)],
          socialPreferences: AppUserSocialPreferences(),
          opdsPreferences: AppUserOpdsPreferences(),
        ),
      ),
    );
    when(mockDao.replaceHighlightSlots(any)).thenAnswer((_) async {});

    await repo.refreshHighlightSlots();

    verify(mockClient.getCurrentUser()).called(1);
    verify(mockDao.replaceHighlightSlots(any)).called(1);
  });

  test(
    'replaceHighlightSlots maps colors and skips missing slot numbers',
    () async {
      when(mockDao.replaceHighlightSlots(any)).thenAnswer((_) async {});

      await repo.replaceHighlightSlots([
        const HighlightSlot(id: 1),
        const HighlightSlot(
          id: 2,
          slotNumber: 0,
          color: RgbaColor(r: 10, g: 20, b: 30, a: 0.75),
        ),
      ]);

      final captured =
          verify(mockDao.replaceHighlightSlots(captureAny)).captured.single
              as Iterable<HighlightSlotsCompanion>;
      final slots = captured.toList();

      expect(slots, hasLength(1));
      expect(slots.single.slotNumber.value, 0);
      expect(slots.single.red.value, 10);
      expect(slots.single.green.value, 20);
      expect(slots.single.blue.value, 30);
      expect(slots.single.alpha.value, 0.75);
    },
  );

  test('watchAnnotation maps stored rows and nulls', () async {
    final stored = storedAnnotation();
    when(mockDao.watchAnnotation(1)).thenAnswer(
      (_) => Stream.fromIterable([stored, null]),
    );

    final values = await repo.watchAnnotation(id: 1).toList();

    expect(values.first?.id, stored.id);
    expect(values.last, isNull);
  });

  test('watchHighlightSlots delegates to the annotation dao', () async {
    when(mockDao.watchHighlightSlots()).thenAnswer((_) => const Stream.empty());

    await repo.watchHighlightSlots().drain<void>();

    verify(mockDao.watchHighlightSlots()).called(1);
  });
}
