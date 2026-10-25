import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/annotation_dao.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:material_ui/material_ui.dart';
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

  AnnotationDto dto({int? id = 1, int? slot = 2, String comment = 'comment'}) {
    return AnnotationDto(
      id: id,
      xPath: '//body/p[1]',
      selectedText: 'text',
      commentPlainText: comment,
      pageNumber: 3,
      selectedSlotIndex: slot,
      chapterId: 1,
      volumeId: 1,
      seriesId: 1,
      libraryId: 1,
      ownerUserId: 1,
    );
  }

  test('refreshChapterAnnotations merges the chapter annotations', () async {
    when(
      mockClient.getChapterAnnotations(1),
    ).thenAnswer((_) async => [dto(), dto(id: null)]);

    await repo.refreshChapterAnnotations(chapterId: 1);

    final entries =
        verify(
              mockDao.mergeAnnotations(captureAny, chapterId: 1),
            ).captured.single
            as Iterable<AnnotationsCompanion>;
    final entry = entries.single;
    expect(entry.serverId.value, 1);
    expect(entry.id.present, isFalse);
    expect(entry.dirty.value, isFalse);
    expect(entry.page.value, 3);
    expect(entry.selectedSlotIndex.value, 2);
    expect(entry.comment.value, 'comment');
  });

  test('decodes the HTML escapes in the note', () {
    final entry = dto(
      comment: 'I&#39;m sure 1 &lt; 2 &amp; 3',
    ).toAnnotationCompanion();

    expect(entry.comment.value, "I'm sure 1 < 2 & 3");
  });

  test('refreshAllAnnotations merges all annotations', () async {
    when(
      mockClient.getAllAnnotations(),
    ).thenAnswer((_) async => [dto(), dto(id: 2)]);

    await repo.refreshAllAnnotations();

    final entries =
        verify(mockDao.mergeAnnotations(captureAny)).captured.single
            as Iterable<AnnotationsCompanion>;
    expect(entries.map((e) => e.serverId.value), [1, 2]);
  });

  test('refreshHighlightSlots stores slots by position', () async {
    when(mockClient.getHighlightSlots()).thenAnswer(
      (_) async => [
        const HighlightSlot(
          slotNumber: 7,
          color: RgbaColor(r: 255, g: 255, b: 0, a: 0.4),
        ),
        const HighlightSlot(
          slotNumber: 3,
          color: RgbaColor(r: 0, g: 0, b: 255, a: 1),
        ),
      ],
    );

    await repo.refreshHighlightSlots();

    final entries =
        verify(
              mockDao.replaceHighlightSlots(captureAny),
            ).captured.single
            as Iterable<HighlightSlotsCompanion>;
    expect(entries.map((e) => e.slotIndex.value), [0, 1]);
    expect(
      entries.map((e) => e.color.value),
      [
        const Color.fromRGBO(255, 255, 0, 0.4).toARGB32(),
        const Color(0xff0000ff).toARGB32(),
      ],
    );
  });
}
