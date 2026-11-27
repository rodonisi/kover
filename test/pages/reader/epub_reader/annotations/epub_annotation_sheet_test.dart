import 'dart:async';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/models/user_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/epub_annotation_draft_sheet.dart';
import 'package:kover/pages/reader/epub_reader/annotations/epub_annotation_sheet.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/utils/annotation_comment.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'epub_annotation_sheet_test.mocks.dart';

const _chapterId = 1;
const _ownerUserId = 1;
const _currentUser = UserModel(id: _ownerUserId, username: 'dev');
const _yellow = Color(0xFFFFFF00);
const _blue = Color(0xFF0000FF);
final _annotation = AnnotationModel(
  id: 10,
  chapterId: _chapterId,
  pageNumber: 4,
  ownerUserId: _ownerUserId,
  ownerUsername: 'dev',
  xPath: '//body/p[1]',
  endingXPath: '//body/p[1]',
  selectedText: 'quoted text',
  commentPlainText: 'original note',
  containsSpoiler: true,
  selectedSlotIndex: 0,
  created: DateTime.utc(2026, 1, 2, 12),
  lastModified: DateTime.utc(2026, 1, 3, 13),
);
const _draft = AnnotationDraft(
  xPath: '//body/p[1]',
  endingXPath: '//body/p[1]',
  selectedText: 'selected words',
  context: 'some selected words in context',
);
final _slots = [
  HighlightSlotModel(slotNumber: 0, color: _yellow),
  HighlightSlotModel(slotNumber: 1, color: _blue),
  HighlightSlotModel(slotNumber: 2),
];
const _toc = [
  BookChapterModel(
    title: 'Prologue',
    page: 0,
    children: [],
  ),
  BookChapterModel(
    title: 'Book One',
    page: 2,
    children: [
      BookChapterModel(title: 'Arrakis', page: 4, children: []),
    ],
  ),
  BookChapterModel(
    title: 'Book Two',
    page: 10,
    children: [],
  ),
];

@GenerateNiceMocks([MockSpec<AnnotationRepository>()])
void main() {
  group('EpubAnnotationSheet', () {
    testWidgets('shows redesigned details without redundant labels', (
      tester,
    ) async {
      await _pumpSheet(tester);

      expect(find.text('Annotation details'), findsNothing);
      expect(find.text('Selected text'), findsNothing);
      expect(find.text('Comment'), findsNothing);
      expect(find.text('Created'), findsNothing);
      expect(find.text('Last Modified'), findsNothing);
      expect(find.byType(Divider), findsNothing);

      expect(find.text('dev'), findsOneWidget);
      expect(find.text('Spoiler'), findsOneWidget);
      expect(find.text('quoted text'), findsOneWidget);
      expect(find.text('Page 5, Chapter "Arrakis"'), findsOneWidget);
      expect(find.text('original note'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
      'shows page-only attribution when TOC has no matching chapter',
      (
        tester,
      ) async {
        await _pumpSheet(tester, toc: const []);

        expect(find.text('Page 5'), findsOneWidget);
      },
    );

    testWidgets('hides edit and delete for annotations owned by another user', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        annotation: _annotation.copyWith(
          ownerUserId: 99,
          ownerUsername: 'other',
        ),
      );

      expect(find.text('other'), findsOneWidget);
      expect(find.text('quoted text'), findsOneWidget);
      expect(find.text('original note'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('hides edit and delete when current user is unknown', (
      tester,
    ) async {
      await _pumpSheet(tester, currentUser: null);

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('shows single lastModified timestamp', (tester) async {
      await _pumpSheet(
        tester,
        annotation: _annotation.copyWith(
          created: DateTime(2025, 4, 10, 9, 0),
          lastModified: DateTime(2026, 11, 25, 14, 30),
        ),
      );

      expect(find.textContaining('2026'), findsOneWidget);
      expect(find.textContaining('2025'), findsNothing);
    });

    testWidgets('renders html comments in view mode', (tester) async {
      await _pumpSheet(
        tester,
        annotation: _annotation.copyWith(
          comment: r'{"ops":[{"insert":"a"},{"attributes":{"list":"bullet"},"insert":"\n"},{"insert":"a"},{"attributes":{"list":"ordered"},"insert":"\n"},{"attributes":{"bold":true},"insert":"asd"},{"insert":"\n"}]}',
          commentHtml: '<ul><li>a</li></ul><ol><li>a</li></ol><p><strong>asd</strong></p>',
          commentPlainText: 'aaasd',
        ),
      );

      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(find.textContaining('asd', findRichText: true), findsOneWidget);
    });

    testWidgets('shows a comment written in the Kavita web app', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        annotation: _annotation.copyWith(
          comment: r'{"ops":[{"insert":"first\nsecond\n"}]}',
          commentHtml: null,
          commentPlainText: 'firstsecond',
        ),
      );

      expect(find.text('first\nsecond'), findsOneWidget);
    });

    testWidgets('shows no comment area for an empty Kavita note', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        annotation: _annotation.copyWith(
          comment: '{}',
          commentHtml: '<p><br></p>',
          commentPlainText: '',
        ),
      );

      expect(find.text('{}'), findsNothing);
      expect(find.byType(HtmlWidget), findsNothing);
    });

    testWidgets(
      'does not overflow on cramped viewports in view and edit mode',
      (
        tester,
      ) async {
        final longQuote = List.generate(20, (i) => 'Quote line $i').join('\n');
        final longComment = List.generate(20, (i) => 'Comment line $i').join(
          '\n',
        );
        final repository = MockAnnotationRepository();
        when(repository.watchAnnotation(id: _annotation.id)).thenAnswer(
          (_) => Stream.value(
            _annotation.copyWith(
              selectedText: longQuote,
              commentPlainText: longComment,
            ),
          ),
        );
        when(
          repository.watchHighlightSlots(),
        ).thenAnswer((_) => Stream.value(_slots));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              annotationRepositoryProvider.overrideWithValue(repository),
              currentUserProvider.overrideWith(
                () => _FakeCurrentUser(_currentUser),
              ),
              bookChaptersProvider(chapterId: _chapterId).overrideWith(
                (_) => Stream.value(_toc),
              ),
            ],
            child: _testApp(
              Scaffold(
                body: SizedBox(
                  height: 400,
                  child: EpubAnnotationSheet(
                    chapterId: _chapterId,
                    annotationId: _annotation.id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await _tap(tester, find.text('Edit'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('saves rich comment, slot, and spoiler toggle', (
      tester,
    ) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Edit'));
      await _setEditorDocument(
        tester,
        quill.Document()
          ..insert(0, 'updated note')
          ..format(0, 7, quill.Attribute.bold),
      );
      await _tap(tester, find.byTooltip('Highlight color 2'));
      await _tap(tester, find.byType(Switch));

      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        repository.updateAnnotation(
          id: 10,
          ownerUserId: _ownerUserId,
          comment: r'{"ops":[{"insert":"updated","attributes":{"bold":true}},{"insert":" note\n"}]}',
          commentHtml: '<p><strong>updated</strong> note</p>',
          commentPlainText: 'updated note',
          containsSpoiler: false,
          selectedSlotIndex: 1,
        ),
      ).called(1);
      expect(find.byType(quill.QuillEditor), findsNothing);
    });

    testWidgets('clears comment fields when the comment is emptied', (
      tester,
    ) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Edit'));
      await _setEditorText(tester, '   ');
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        repository.updateAnnotation(
          id: 10,
          ownerUserId: _ownerUserId,
          comment: null,
          commentHtml: null,
          commentPlainText: null,
          containsSpoiler: true,
          selectedSlotIndex: 0,
        ),
      ).called(1);
    });

    testWidgets('omits slots without colors', (tester) async {
      await _pumpSheet(tester);

      await _tap(tester, find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Highlight color 1'), findsOneWidget);
      expect(find.byTooltip('Highlight color 2'), findsOneWidget);
      expect(find.byTooltip('Highlight color 3'), findsNothing);
    });

    testWidgets('does not delete when confirmation is cancelled', (
      tester,
    ) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(repository.removeAnnotation(10, ownerUserId: _ownerUserId));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('deletes after confirmation', (tester) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      verify(repository.removeAnnotation(10, ownerUserId: _ownerUserId))
          .called(1);
    });

    testWidgets('shows an error when saving fails', (tester) async {
      final repository = await _pumpSheet(tester);
      when(
        repository.updateAnnotation(
          id: 10,
          ownerUserId: _ownerUserId,
          comment: r'{"ops":[{"insert":"bad note\n"}]}',
          commentHtml: '<p>bad note</p>',
          commentPlainText: 'bad note',
          containsSpoiler: true,
          selectedSlotIndex: 0,
        ),
      ).thenThrow(StateError('save failed'));

      await _tap(tester, find.text('Edit'));
      await tester.pumpAndSettle();
      await _setEditorText(tester, 'bad note');
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save annotation.'), findsOneWidget);
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('shows an error when deletion fails', (tester) async {
      final repository = await _pumpSheet(tester);
      when(repository.removeAnnotation(10, ownerUserId: _ownerUserId))
          .thenThrow(StateError('delete failed'));

      await _tap(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pump();

      expect(find.text('Could not delete annotation.'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows a message when the annotation no longer exists', (
      tester,
    ) async {
      await _pumpSheet(tester, exists: false);

      expect(find.text('Annotation not found.'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('updates details when the annotation stream changes', (
      tester,
    ) async {
      final annotations = StreamController<AnnotationModel?>();
      addTearDown(annotations.close);
      annotations.add(_annotation);
      await _pumpSheet(
        tester,
        annotationStream: annotations.stream,
      );

      annotations.add(
        _annotation.copyWith(commentPlainText: 'updated externally'),
      );
      await tester.pumpAndSettle();

      expect(find.text('updated externally'), findsOneWidget);
      expect(find.text('original note'), findsNothing);
    });

    testWidgets(
      'keeps details mounted during delete and does not pop reader if dismissed',
      (tester) async {
        final annotations = StreamController<AnnotationModel?>();
        addTearDown(annotations.close);
        annotations.add(_annotation);
        final pendingRemove = Completer<void>();
        final repository = MockAnnotationRepository();
        when(
          repository.watchAnnotation(id: 10),
        ).thenAnswer((_) => annotations.stream);
        when(
          repository.watchHighlightSlots(),
        ).thenAnswer((_) => Stream.value(_slots));
        when(repository.removeAnnotation(10, ownerUserId: _ownerUserId))
            .thenAnswer((_) => pendingRemove.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              annotationRepositoryProvider.overrideWithValue(repository),
              currentUserProvider.overrideWith(
                () => _FakeCurrentUser(_currentUser),
              ),
              bookChaptersProvider(chapterId: _chapterId).overrideWith(
                (_) => Stream.value(_toc),
              ),
            ],
            child: _testApp(
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) => Scaffold(
                          body: Column(
                            children: [
                              const Text('reader screen'),
                              TextButton(
                                onPressed: () => showModalBottomSheet<void>(
                                  context: routeContext,
                                  isScrollControlled: true,
                                  builder: (_) => EpubAnnotationSheet(
                                    chapterId: _chapterId,
                                    annotationId: _annotation.id,
                                  ),
                                ),
                                child: const Text('open'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: const Text('enter reader'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('enter reader'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await _tap(tester, find.text('Delete'));
        await tester.pumpAndSettle();
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
        );
        await tester.pump();

        expect(find.text('Annotation not found.'), findsNothing);
        expect(find.text('quoted text'), findsOneWidget);

        // Dismiss the sheet before the server call completes.
        Navigator.of(tester.element(find.text('quoted text'))).pop();
        await tester.pumpAndSettle();

        pendingRemove.complete();
        await tester.pumpAndSettle();

        expect(find.text('reader screen'), findsOneWidget);
      },
    );
  });

  group('EpubAnnotationDraftSheet', () {
    testWidgets('opens in edit mode without title or redundant labels', (
      tester,
    ) async {
      await _pumpDraftSheet(tester);

      expect(find.text('New annotation'), findsNothing);
      expect(find.text('Selected text'), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(find.text('selected words'), findsOneWidget);
      expect(find.text('Page 5, Chapter "Arrakis"'), findsOneWidget);
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(quill.QuillSimpleToolbar), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(Switch)).dx,
        greaterThan(
          tester.getTopRight(find.byTooltip('Highlight color 2')).dx,
        ),
      );
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('creates the annotation with spoiler and closes', (
      tester,
    ) async {
      final actions = await _pumpDraftSheet(tester);

      await _setEditorText(tester, '  a note  ');
      await _tap(tester, find.byTooltip('Highlight color 2'));
      await _tap(tester, find.byType(Switch));
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.created, [
        (
          chapterId: _chapterId,
          pageNumber: 4,
          draft: _draft,
          comment: 'a note',
          containsSpoiler: true,
          selectedSlotIndex: 1,
        ),
      ]);
      expect(find.text('selected words'), findsNothing);
    });

    testWidgets('creates an annotation without a comment', (tester) async {
      final actions = await _pumpDraftSheet(tester);

      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.created.single.comment, isNull);
      expect(actions.created.single.containsSpoiler, isFalse);
      expect(actions.created.single.selectedSlotIndex, 0);
    });

    testWidgets('preselects the first slot that has a color', (tester) async {
      final actions = await _pumpDraftSheet(
        tester,
        slots: [
          HighlightSlotModel(slotNumber: 0),
          HighlightSlotModel(slotNumber: 1, color: _blue),
        ],
      );

      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.created.single.selectedSlotIndex, 1);
    });

    testWidgets('closes without creating when cancelled', (tester) async {
      final actions = await _pumpDraftSheet(tester);

      await _tap(tester, find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(actions.created, isEmpty);
      expect(find.text('selected words'), findsNothing);
    });

    testWidgets('stays open and shows an error when creating fails', (
      tester,
    ) async {
      final actions = await _pumpDraftSheet(tester);
      actions.error = StateError('create failed');

      await _tap(tester, find.text('Save'));
      await tester.pump();

      expect(find.text('Could not save annotation.'), findsOneWidget);
      expect(find.text('selected words'), findsOneWidget);
    });

    testWidgets('does not pop reader if dismissed while save is pending', (
      tester,
    ) async {
      final pendingCreate = Completer<void>();
      final actions = _DraftActionRecorder(pending: pendingCreate);
      final repository = MockAnnotationRepository();
      when(
        repository.watchHighlightSlots(),
      ).thenAnswer((_) => Stream.value(_slots));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            annotationRepositoryProvider.overrideWithValue(repository),
            bookChaptersProvider(chapterId: _chapterId).overrideWith(
              (_) => Stream.value(_toc),
            ),
            annotationActionsProvider.overrideWith(
              () => _RecordingAnnotationActions(actions),
            ),
          ],
          child: _testApp(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (routeContext) => Scaffold(
                        body: Column(
                          children: [
                            const Text('reader screen'),
                            TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                context: routeContext,
                                isScrollControlled: true,
                                builder: (_) => const EpubAnnotationDraftSheet(
                                  chapterId: _chapterId,
                                  pageNumber: 4,
                                  draft: _draft,
                                ),
                              ),
                              child: const Text('open'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('enter reader'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('enter reader'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Save'));
      await tester.pump();

      // Dismiss the sheet before create completes.
      Navigator.of(tester.element(find.text('selected words'))).pop();
      await tester.pumpAndSettle();

      pendingCreate.complete();
      await tester.pumpAndSettle();

      expect(find.text('reader screen'), findsOneWidget);
    });
  });
}

typedef _Created = ({
  int chapterId,
  int pageNumber,
  AnnotationDraft draft,
  String? comment,
  bool containsSpoiler,
  int selectedSlotIndex,
});

class _DraftActionRecorder({final Completer<void>? pending}) {
  final created = <_Created>[];
  Object? error;
}

class _RecordingAnnotationActions(final _DraftActionRecorder _recorder)
    extends AnnotationActions {
  @override
  Future<void> create({
    required int chapterId,
    required int pageNumber,
    required AnnotationDraft draft,
    required quill.Document? comment,
    bool containsSpoiler = false,
    required int selectedSlotIndex,
  }) async {
    if (_recorder.error case final error?) throw error;
    if (_recorder.pending case final pending?) {
      await pending.future;
    }

    final encoded = comment == null
        ? AnnotationComment.empty
        : AnnotationComment.fromDocument(comment);

    _recorder.created.add((
      chapterId: chapterId,
      pageNumber: pageNumber,
      draft: draft,
      comment: encoded.commentPlainText,
      containsSpoiler: containsSpoiler,
      selectedSlotIndex: selectedSlotIndex,
    ));
  }
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      ...GlobalMaterialLocalizations.delegates,
      quill.FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      // ignore: deprecated_member_use
      return MaterialUiCompatibilityBridge(child: child!);
    },
    home: home,
  );
}

/// Opens the draft sheet as a modal bottom sheet, like the reader does.
Future<_DraftActionRecorder> _pumpDraftSheet(
  WidgetTester tester, {
  List<HighlightSlotModel>? slots,
  List<BookChapterModel>? toc,
}) async {
  final recorder = _DraftActionRecorder();
  final repository = MockAnnotationRepository();
  when(
    repository.watchHighlightSlots(),
  ).thenAnswer((_) => Stream.value(slots ?? _slots));

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        annotationRepositoryProvider.overrideWithValue(repository),
        bookChaptersProvider(chapterId: _chapterId).overrideWith(
          (_) => Stream.value(toc ?? _toc),
        ),
        annotationActionsProvider.overrideWith(
          () => _RecordingAnnotationActions(recorder),
        ),
      ],
      child: _testApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => const EpubAnnotationDraftSheet(
                  chapterId: _chapterId,
                  pageNumber: 4,
                  draft: _draft,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return recorder;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _setEditorText(WidgetTester tester, String value) async {
  await _setEditorDocument(
    tester,
    value.isEmpty ? quill.Document() : (quill.Document()..insert(0, value)),
  );
}

Future<void> _setEditorDocument(
  WidgetTester tester,
  quill.Document document,
) async {
  final editor = tester.widget<quill.QuillEditor>(
    find.byType(quill.QuillEditor),
  );
  editor.controller.document = document;
  await tester.pump();
}

class _FakeCurrentUser(final UserModel? _user) extends CurrentUser {
  @override
  Future<UserModel> build() {
    final user = _user;
    if (user == null) {
      return Future<UserModel>.error(NoCredentialsException());
    }
    return Future.value(user);
  }
}

Future<MockAnnotationRepository> _pumpSheet(
  WidgetTester tester, {
  AnnotationModel? annotation,
  bool exists = true,
  List<HighlightSlotModel>? slots,
  List<BookChapterModel>? toc,
  UserModel? currentUser = _currentUser,
  Stream<AnnotationModel?>? annotationStream,
  Stream<List<HighlightSlotModel>>? slotsStream,
}) async {
  final repository = MockAnnotationRepository();
  when(repository.watchAnnotation(id: _annotation.id)).thenAnswer(
    (_) =>
        annotationStream ??
        Stream.value(exists ? annotation ?? _annotation : null),
  );
  when(
    repository.watchHighlightSlots(),
  ).thenAnswer((_) => slotsStream ?? Stream.value(slots ?? _slots));

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        annotationRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWith(() => _FakeCurrentUser(currentUser)),
        bookChaptersProvider(chapterId: _chapterId).overrideWith(
          (_) => Stream.value(toc ?? _toc),
        ),
      ],
      child: _testApp(
        Scaffold(
          body: EpubAnnotationSheet(
            chapterId: _chapterId,
            annotationId: _annotation.id,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}
