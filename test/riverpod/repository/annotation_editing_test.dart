import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart'
    show AnnotationDto, $AnnotationDtoExtension;
import 'package:kover/database/app_database.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:kover/utils/quill_note.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<AnnotationSyncOperations>()])
import 'annotation_editing_test.mocks.dart';

void main() {
  late AppDatabase db;
  late MockAnnotationSyncOperations client;
  late AnnotationRepository repo;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db
        .into(db.series)
        .insert(
          SeriesCompanion.insert(
            id: const Value(1),
            libraryId: 7,
            name: 'S',
            format: Format.epub,
            created: DateTime.now(),
          ),
        );
    await db
        .into(db.volumes)
        .insert(
          VolumesCompanion.insert(
            id: const Value(3),
            seriesId: 1,
            minNumber: 0,
            maxNumber: 0,
            pages: 10,
            created: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: const Value(5),
            volumeId: 3,
            seriesId: 1,
            format: Format.epub,
            minNumber: 0,
            maxNumber: 0,
            sortOrder: 0,
            ageRating: AgeRating.unknown,
            publicationStatus: PublicationStatus.unknown,
            wordCount: 0,
            releaseDate: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            pages: 10,
          ),
        );

    client = MockAnnotationSyncOperations();
    repo = AnnotationRepository(db, client);
  });

  tearDown(() => db.close());

  AnnotationDto serverCopy({String? comment, String? commentHtml}) {
    return AnnotationDto(
      id: 42,
      xPath: '//body/p[2]',
      endingXPath: '//body/p[2]',
      selectedText: 'Some text',
      comment: comment ?? QuillNote.delta('Note'),
      commentHtml: commentHtml ?? QuillNote.html('Note'),
      selectedSlotIndex: 1,
      containsSpoiler: false,
      pageNumber: 4,
      chapterId: 5,
      volumeId: 3,
      seriesId: 1,
      libraryId: 7,
      ownerUserId: 9,
    );
  }

  Future<AnnotationModel> create(AnnotationDto dto) {
    return repo.createAnnotation(
      seriesId: 1,
      volumeId: 3,
      chapterId: 5,
      page: 4,
      ownerUserId: 9,
      xPath: dto.xPath!,
      endingXPath: dto.endingXPath!,
      selectedText: dto.selectedText!,
      context: 'Some text in context',
      comment: 'Note',
      selectedSlotIndex: 1,
      containsSpoiler: false,
    );
  }

  Future<AnnotationModel> storeServerCopy(AnnotationDto dto) {
    when(client.create(any)).thenAnswer((_) async => dto);
    return create(dto);
  }

  Future<List<Annotation>> stored() => db.select(db.annotations).get();

  group('createAnnotation', () {
    test('sends what Kavita needs and stores its copy', () async {
      when(client.create(any)).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments.single as AnnotationDto).copyWith(
              id: 42,
            ),
      );

      final created = await repo.createAnnotation(
        seriesId: 1,
        volumeId: 3,
        chapterId: 5,
        page: 4,
        ownerUserId: 9,
        xPath: '//body/p[2]',
        endingXPath: '//body/p[3]',
        selectedText: 'Some text',
        context: 'Some text in context',
        comment: "It's\nmine",
        selectedSlotIndex: 2,
        containsSpoiler: true,
      );

      final sent =
          verify(client.create(captureAny)).captured.single as AnnotationDto;
      expect(sent.xPath, '//body/p[2]');
      expect(sent.endingXPath, '//body/p[3]');
      expect(sent.selectedText, 'Some text');
      expect(sent.highlightCount, 9);
      expect(sent.context, 'Some text in context');
      expect(sent.comment, r'''{"ops":[{"insert":"It's\nmine\n"}]}''');
      expect(sent.commentHtml, '<p>It&#39;s</p><p>mine</p>');
      expect(sent.pageNumber, 4);
      expect(sent.selectedSlotIndex, 2);
      expect(sent.containsSpoiler, isTrue);
      expect(
        (sent.seriesId, sent.volumeId, sent.chapterId, sent.libraryId),
        (1, 3, 5, 7),
      );
      expect(sent.createdUtc, isNull);

      expect(created.serverId, 42);
      expect(created.comment, "It's\nmine");
      expect((await stored()).single.dirty, isFalse);
    });

    test('throws and stores nothing when the server fails', () async {
      when(client.create(any)).thenThrow(Exception('offline'));

      await expectLater(create(serverCopy()), throwsException);
      expect(await stored(), isEmpty);
    });
  });

  group('updateAnnotation', () {
    test('keeps a note formatted elsewhere when only the color changes', () async {
      const formatted =
          '{"ops":[{"insert":"Note","attributes":{"bold":true}},{"insert":"\\n"}]}';
      final annotation = await storeServerCopy(serverCopy());
      when(client.get(42)).thenAnswer(
        (_) async => serverCopy(
          comment: formatted,
          commentHtml: '<p><strong>Note</strong></p>',
        ),
      );
      when(client.update(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments.single,
      );

      final pushed = await repo.updateAnnotation(
        annotation,
        comment: 'Note',
        selectedSlotIndex: 3,
        containsSpoiler: true,
      );

      final sent =
          verify(client.update(captureAny)).captured.single as AnnotationDto;
      expect(pushed, isTrue);
      expect(sent.comment, formatted);
      expect(sent.commentHtml, '<p><strong>Note</strong></p>');
      expect(sent.selectedSlotIndex, 3);
      expect(sent.containsSpoiler, isTrue);
      final row = (await stored()).single;
      expect((row.selectedSlotIndex, row.dirty), (3, false));
    });

    test('rewrites the note when it changed', () async {
      final annotation = await storeServerCopy(serverCopy());
      when(client.get(42)).thenAnswer((_) async => serverCopy());
      when(client.update(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments.single,
      );

      await repo.updateAnnotation(
        annotation,
        comment: 'Better note',
        selectedSlotIndex: 1,
        containsSpoiler: false,
      );

      final sent =
          verify(client.update(captureAny)).captured.single as AnnotationDto;
      expect(sent.comment, QuillNote.delta('Better note'));
      expect(sent.commentHtml, QuillNote.html('Better note'));
      expect((await stored()).single.comment, 'Better note');
    });

    test('keeps an offline change until the next push', () async {
      final annotation = await storeServerCopy(serverCopy());
      when(client.get(42)).thenThrow(Exception('offline'));

      final pushed = await repo.updateAnnotation(
        annotation,
        comment: 'Offline note',
        selectedSlotIndex: 2,
        containsSpoiler: false,
      );

      expect(pushed, isFalse);
      final row = (await stored()).single;
      expect(
        (row.comment, row.selectedSlotIndex, row.dirty),
        (
          'Offline note',
          2,
          true,
        ),
      );

      when(client.get(42)).thenAnswer((_) async => serverCopy());
      when(client.update(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments.single,
      );
      await repo.pushAnnotations();

      final sent =
          verify(client.update(captureAny)).captured.single as AnnotationDto;
      expect(sent.comment, QuillNote.delta('Offline note'));
      expect((await stored()).single.dirty, isFalse);
    });
  });

  group('deleteAnnotation', () {
    test('deletes on the server and locally', () async {
      final annotation = await storeServerCopy(serverCopy());

      expect(await repo.deleteAnnotation(annotation), isTrue);

      verify(client.delete(42)).called(1);
      expect(await stored(), isEmpty);
    });

    test('hides an offline deletion until the next push', () async {
      final annotation = await storeServerCopy(serverCopy());
      when(client.delete(42)).thenThrow(Exception('offline'));

      expect(await repo.deleteAnnotation(annotation), isFalse);
      expect(await repo.watchSeriesAnnotations(seriesId: 1).first, isEmpty);
      expect((await stored()).single.deleted, isTrue);

      when(client.delete(42)).thenAnswer((_) async {});
      await repo.pushAnnotations();

      expect(await stored(), isEmpty);
    });

    test('forgets an annotation the server deleted meanwhile', () async {
      final annotation = await storeServerCopy(serverCopy());
      when(client.get(42)).thenAnswer((_) async => null);

      await repo.updateAnnotation(
        annotation,
        comment: 'Note',
        selectedSlotIndex: 0,
        containsSpoiler: false,
      );

      verifyNever(client.update(any));
      expect(await stored(), isEmpty);
    });
  });
}
