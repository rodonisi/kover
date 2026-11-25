import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart' hide HighlightSlot;
import 'package:kover/database/dao/annotation_dao.dart';
import 'package:kover/database/dao/highlight_slot_dao.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AppDatabase>(),
  MockSpec<AnnotationDao>(),
  MockSpec<HighlightSlotDao>(),
  MockSpec<AnnotationSyncOperations>(),
])
import 'annotation_repository_test.mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockAnnotationDao mockDao;
  late MockHighlightSlotDao mockSlotDao;
  late MockAnnotationSyncOperations mockClient;
  late AnnotationRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockDao = MockAnnotationDao();
    mockSlotDao = MockHighlightSlotDao();
    mockClient = MockAnnotationSyncOperations();
    when(mockDb.annotationDao).thenReturn(mockDao);
    when(mockDb.highlightSlotDao).thenReturn(mockSlotDao);
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
      pageNumber: 1,
      selectedSlotIndex: 0,
      likes: const [],
      created: DateTime(2026),
      lastModified: lastModified,
      dirty: dirty,
      removed: removed,
    );
  }

  AnnotationDto remoteAnnotation({int id = 9, int chapterId = 1}) {
    return AnnotationDto(
      id: id,
      xPath: '/p[1]',
      selectedText: 'text',
      pageNumber: 1,
      selectedSlotIndex: 0,
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
    when(mockDao.getAnnotation(1)).thenAnswer((_) async => stored);
    when(mockClient.create(any)).thenAnswer((_) async => remoteAnnotation());

    await repo.addAnnotation(
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      libraryId: 1,
      ownerUserId: 1,
      xPath: '/p[1]',
      selectedText: 'text',
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
      selectedText: 'text',
      pageNumber: 1,
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
    var calls = 0;
    when(mockDao.getAnnotation(1)).thenAnswer((_) async {
      return calls++ == 0
          ? storedAnnotation(serverId: 9)
          : storedAnnotation(serverId: 9, dirty: true, removed: true);
    });
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
    when(mockDao.getAnnotation(1)).thenAnswer((_) async => create);
    when(mockDao.getAnnotation(2)).thenAnswer((_) async => update);
    when(mockDao.getAnnotation(3)).thenAnswer((_) async => remove);
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

  test(
    'cleans up remote copy when an unsynced annotation is deleted mid-create',
    () async {
      final stored = storedAnnotation(dirty: true);
      final createCompleter = Completer<AnnotationDto>();
      Annotation? current = stored;

      when(mockDao.upsert(any)).thenAnswer((_) async => stored);
      when(mockDao.getAnnotation(1)).thenAnswer((_) async => current);
      when(mockClient.create(any)).thenAnswer((_) => createCompleter.future);
      when(mockClient.remove(9)).thenAnswer((_) async {});

      final addFuture = repo.addAnnotation(
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        libraryId: 1,
        ownerUserId: 1,
        selectedText: 'text',
        pageNumber: 1,
      );
      await Future<void>.delayed(Duration.zero);

      // Simulate local hard-delete while create is still in flight.
      current = null;
      createCompleter.complete(remoteAnnotation(id: 9));
      await addFuture;

      verify(mockClient.remove(9)).called(1);
      verify(mockDao.upsert(any)).called(1);
    },
  );

  test(
    'keeps newer local edit dirty when an earlier create returns',
    () async {
      final firstTime = DateTime(2026, 1, 1, 12);
      final secondTime = DateTime(2026, 1, 1, 12, 1);
      final stored = storedAnnotation(dirty: true, lastModified: firstTime);
      final createCompleter = Completer<AnnotationDto>();
      var current = stored;

      when(mockDao.upsert(any)).thenAnswer((_) async => current);
      when(mockDao.getAnnotation(1)).thenAnswer((_) async => current);
      when(mockClient.create(any)).thenAnswer((_) => createCompleter.future);

      final addFuture = repo.addAnnotation(
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        libraryId: 1,
        ownerUserId: 1,
        selectedText: 'text',
        pageNumber: 1,
      );
      await Future<void>.delayed(Duration.zero);

      current = stored.copyWith(lastModified: Value(secondTime));
      createCompleter.complete(remoteAnnotation(id: 9));
      await addFuture;

      final captured = verify(mockDao.upsert(captureAny)).captured;
      expect(captured, hasLength(2));
      final patch = captured.last as AnnotationsCompanion;
      expect(patch.serverId.value, 9);
      expect(patch.dirty.value, isTrue);
      expect(patch.comment.present, isFalse);
    },
  );

  test(
    'removes remote copy when annotation is tombstoned mid-push',
    () async {
      final stored = storedAnnotation(id: 1, serverId: 9, dirty: true);
      final updateCompleter = Completer<AnnotationDto>();
      var current = stored;

      when(mockDao.getDirtyAnnotations()).thenAnswer((_) async => [stored]);
      when(mockDao.getAnnotation(1)).thenAnswer((_) async => current);
      when(mockClient.update(any)).thenAnswer((_) => updateCompleter.future);
      when(mockClient.remove(9)).thenAnswer((_) async {});

      final mergeFuture = repo.mergeAnnotations();
      await Future<void>.delayed(Duration.zero);

      current = stored.copyWith(removed: true);
      updateCompleter.complete(remoteAnnotation(id: 9));
      await mergeFuture;

      verify(mockClient.remove(9)).called(1);
      verify(mockDao.deleteByIds([1])).called(1);
      verifyNever(mockDao.upsert(any));
    },
  );

  test(
    'serializes concurrent pushes for the same annotation without double create',
    () async {
      final stored = storedAnnotation(id: 1, dirty: true);
      final createCompleter = Completer<AnnotationDto>();
      var current = stored;

      when(mockDao.upsert(any)).thenAnswer((invocation) async {
        final companion =
            invocation.positionalArguments.single as AnnotationsCompanion;
        if (companion.serverId.present && companion.dirty.present) {
          current = current.copyWith(
            serverId: Value(companion.serverId.value),
            dirty: companion.dirty.value,
          );
        }
        return current;
      });
      when(mockDao.getAnnotation(1)).thenAnswer((_) async => current);
      when(mockDao.getDirtyAnnotations()).thenAnswer((_) async => [stored]);
      when(mockClient.create(any)).thenAnswer((_) => createCompleter.future);

      final addFuture = repo.addAnnotation(
        seriesId: 1,
        volumeId: 1,
        chapterId: 1,
        libraryId: 1,
        ownerUserId: 1,
        selectedText: 'text',
        pageNumber: 1,
      );
      await Future<void>.delayed(Duration.zero);

      final mergeFuture = repo.mergeAnnotations();
      createCompleter.complete(remoteAnnotation(id: 9));
      await Future.wait([addFuture, mergeFuture]);

      verify(mockClient.create(any)).called(1);
      verifyNever(mockClient.update(any));
    },
  );

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

  test(
    'replaceHighlightSlots maps colors and skips missing slot numbers',
    () async {
      when(mockSlotDao.replaceSlots(any)).thenAnswer((_) async {});

      await repo.replaceHighlightSlots([
        const HighlightSlot(id: 1),
        const HighlightSlot(
          id: 2,
          slotNumber: 0,
          color: RgbaColor(r: 10, g: 20, b: 30, a: 0.75),
        ),
      ]);

      final captured =
          verify(mockSlotDao.replaceSlots(captureAny)).captured.single
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

  test('watchHighlightSlots delegates to the slot dao', () async {
    when(mockSlotDao.watchSlots()).thenAnswer((_) => const Stream.empty());

    await repo.watchHighlightSlots().drain<void>();

    verify(mockSlotDao.watchSlots()).called(1);
  });
}
