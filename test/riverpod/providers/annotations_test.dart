import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/models/user_model.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/riverpod/repository/chapters_repository.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<AnnotationRepository>(),
  MockSpec<ChaptersRepository>(),
  MockSpec<SeriesRepository>(),
])
import 'annotations_test.mocks.dart';

const _chapter = ChapterModel(
  id: 3,
  seriesId: 1,
  volumeId: 2,
  title: 'Chapter',
  pages: 10,
);
const _series = SeriesModel(
  id: 1,
  libraryId: 4,
  name: 'Series',
  format: .epub,
  pages: 10,
  avgHoursToRead: 0,
  wordCount: null,
  primaryColor: null,
  secondaryColor: null,
  lastSynced: null,
);
const _draft = AnnotationDraft(
  xPath: '//body/p[1]',
  endingXPath: '//body/p[2]',
  selectedText: 'one\n\ntwo',
  context: 'two and more',
);

class _FakeCurrentUser extends CurrentUser {
  @override
  Future<UserModel> build() async => const UserModel(id: 5, username: 'user');
}

void main() {
  provideDummy<ChapterModel>(_chapter);
  provideDummy<SeriesModel>(_series);

  group('AnnotationActions', () {
    late MockAnnotationRepository annotations;
    late ProviderContainer container;

    setUp(() {
      annotations = MockAnnotationRepository();
      final chapters = MockChaptersRepository();
      final series = MockSeriesRepository();
      when(chapters.getChapter(chapterId: 3)).thenAnswer((_) async => _chapter);
      when(series.getSeries(seriesId: 1)).thenAnswer((_) async => _series);

      container = ProviderContainer.test(
        overrides: [
          annotationRepositoryProvider.overrideWithValue(annotations),
          chaptersRepositoryProvider.overrideWithValue(chapters),
          seriesRepositoryProvider.overrideWithValue(series),
          currentUserProvider.overrideWith(_FakeCurrentUser.new),
        ],
      );
    });

    test('create fills the annotation like the Kavita web app', () async {
      final document = quill.Document()..insert(0, 'a note');
      await container
          .read(annotationActionsProvider.notifier)
          .create(
            chapterId: 3,
            pageNumber: 7,
            draft: _draft,
            comment: document,
            containsSpoiler: true,
            selectedSlotIndex: 2,
          );

      verify(
        annotations.addAnnotation(
          seriesId: 1,
          volumeId: 2,
          chapterId: 3,
          libraryId: 4,
          ownerUserId: 5,
          ownerUsername: 'user',
          xPath: '//body/p[1]',
          endingXPath: '//body/p[2]',
          selectedText: 'one\n\ntwo',
          comment: r'{"ops":[{"insert":"a note\n"}]}',
          commentHtml: '<p>a note</p>',
          context: 'two and more',
          highlightCount: 8,
          containsSpoiler: true,
          pageNumber: 7,
          selectedSlotIndex: 2,
        ),
      ).called(1);
    });

    test('create leaves the comment empty without a note', () async {
      await container
          .read(annotationActionsProvider.notifier)
          .create(
            chapterId: 3,
            pageNumber: 7,
            draft: _draft,
            comment: quill.Document(),
            selectedSlotIndex: 0,
          );

      verify(
        annotations.addAnnotation(
          seriesId: 1,
          volumeId: 2,
          chapterId: 3,
          libraryId: 4,
          ownerUserId: 5,
          ownerUsername: 'user',
          xPath: '//body/p[1]',
          endingXPath: '//body/p[2]',
          selectedText: 'one\n\ntwo',
          comment: '{}',
          commentHtml: null,
          context: 'two and more',
          highlightCount: 8,
          containsSpoiler: false,
          pageNumber: 7,
          selectedSlotIndex: 0,
        ),
      ).called(1);
    });

    test('save encodes the comment for Kavita', () async {
      final document = quill.Document()
        ..insert(0, 'first\nsecond')
        ..format(0, 5, quill.Attribute.bold);
      await container
          .read(annotationActionsProvider.notifier)
          .save(
            id: 10,
            comment: document,
            containsSpoiler: true,
            selectedSlotIndex: 1,
          );

      verify(
        annotations.updateAnnotation(
          id: 10,
          ownerUserId: 5,
          comment: r'{"ops":[{"insert":"first","attributes":{"bold":true}},{"insert":"\nsecond\n"}]}',
          commentHtml: '<p><strong>first</strong></p><p>second</p>',
          containsSpoiler: true,
          selectedSlotIndex: 1,
        ),
      ).called(1);
    });

    test('remove forwards the current user id', () async {
      await container.read(annotationActionsProvider.notifier).remove(10);

      verify(annotations.removeAnnotation(10, ownerUserId: 5)).called(1);
    });
  });
}
