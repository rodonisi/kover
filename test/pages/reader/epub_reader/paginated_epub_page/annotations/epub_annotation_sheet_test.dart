import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/annotations/epub_annotation_sheet.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'epub_annotation_sheet_test.mocks.dart';

const _chapterId = 1;
const _yellow = Color(0xFFFFFF00);
const _blue = Color(0xFF0000FF);
final _annotation = AnnotationModel(
  id: 10,
  chapterId: _chapterId,
  pageNumber: 4,
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

@GenerateNiceMocks([MockSpec<AnnotationRepository>()])
void main() {
  group('EpubAnnotationSheet', () {
    testWidgets('shows annotation details', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Annotation details'), findsOneWidget);
      expect(find.text('quoted text'), findsOneWidget);
      expect(find.text('original note'), findsOneWidget);
      expect(find.text('Spoiler'), findsOneWidget);
      expect(find.text('Page'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Last Modified'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('shows a comment written in the Kavita web app', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        annotations: [
          _annotation.copyWith(
            comment: r'{"ops":[{"insert":"first\nsecond\n"}]}',
            commentPlainText: 'firstsecond',
          ),
        ],
      );

      expect(find.text('first\nsecond'), findsOneWidget);
    });

    testWidgets('shows no comment for an empty Kavita note', (tester) async {
      await _pumpSheet(
        tester,
        annotations: [
          _annotation.copyWith(comment: '{}', commentPlainText: ''),
        ],
      );

      expect(find.text('Comment'), findsNothing);
      expect(find.text('{}'), findsNothing);
    });

    testWidgets('saves a trimmed comment and selected slot', (tester) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Edit'));
      await _enterText(
        tester,
        find.byKey(const ValueKey('annotation-comment-field')),
        '  updated note  ',
      );
      await _tap(tester, find.byTooltip('Highlight color 2'));
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        repository.updateAnnotation(
          id: 10,
          comment: r'{"ops":[{"insert":"updated note\n"}]}',
          commentHtml: '<p>updated note</p>',
          commentPlainText: 'updated note',
          containsSpoiler: true,
          selectedSlotIndex: 1,
        ),
      ).called(1);
      expect(
        find.byKey(const ValueKey('annotation-comment-field')),
        findsNothing,
      );
    });

    testWidgets('clears comment fields when the comment is emptied', (
      tester,
    ) async {
      final repository = await _pumpSheet(tester);

      await _tap(tester, find.text('Edit'));
      await _enterText(
        tester,
        find.byKey(const ValueKey('annotation-comment-field')),
        '   ',
      );
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        repository.updateAnnotation(
          id: 10,
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
      await tester.pump();

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

      verifyNever(repository.removeAnnotation(10));
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

      verify(repository.removeAnnotation(10)).called(1);
    });

    testWidgets('shows an error when saving fails', (tester) async {
      final repository = await _pumpSheet(tester);
      when(
        repository.updateAnnotation(
          id: 10,
          comment: r'{"ops":[{"insert":"bad note\n"}]}',
          commentHtml: '<p>bad note</p>',
          commentPlainText: 'bad note',
          containsSpoiler: true,
          selectedSlotIndex: 0,
        ),
      ).thenThrow(StateError('save failed'));

      await _tap(tester, find.text('Edit'));
      await _enterText(
        tester,
        find.byKey(const ValueKey('annotation-comment-field')),
        'bad note',
      );
      await _tap(tester, find.text('Save'));
      await tester.pump();

      expect(find.text('Could not save annotation.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('annotation-comment-field')),
        findsOneWidget,
      );
    });

    testWidgets('shows an error when deletion fails', (tester) async {
      final repository = await _pumpSheet(tester);
      when(repository.removeAnnotation(10))
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
      await _pumpSheet(tester, annotations: []);

      expect(find.text('Annotation not found.'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('updates details when the annotation stream changes', (
      tester,
    ) async {
      final annotations = StreamController<List<AnnotationModel>>();
      addTearDown(annotations.close);
      annotations.add([_annotation]);
      await _pumpSheet(
        tester,
        annotationsStream: annotations.stream,
      );

      annotations.add([
        _annotation.copyWith(commentPlainText: 'updated externally'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('updated externally'), findsOneWidget);
      expect(find.text('original note'), findsNothing);
    });
  });

  group('EpubAnnotationDraftSheet', () {
    testWidgets('opens in edit mode with the selected text', (tester) async {
      await _pumpDraftSheet(tester);

      expect(find.text('New annotation'), findsOneWidget);
      expect(find.text('selected words'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('annotation-comment-field')),
        findsOneWidget,
      );
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('creates the annotation and closes', (tester) async {
      final actions = await _pumpDraftSheet(tester);

      await _enterText(
        tester,
        find.byKey(const ValueKey('annotation-comment-field')),
        '  a note  ',
      );
      await _tap(tester, find.byTooltip('Highlight color 2'));
      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.created, [
        (
          chapterId: _chapterId,
          pageNumber: 4,
          draft: _draft,
          comment: 'a note',
          selectedSlotIndex: 1,
        ),
      ]);
      expect(find.text('New annotation'), findsNothing);
    });

    testWidgets('creates an annotation without a comment', (tester) async {
      final actions = await _pumpDraftSheet(tester);

      await _tap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.created.single.comment, isNull);
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
      expect(find.text('New annotation'), findsNothing);
    });

    testWidgets('stays open and shows an error when creating fails', (
      tester,
    ) async {
      final actions = await _pumpDraftSheet(tester);
      actions.error = StateError('create failed');

      await _tap(tester, find.text('Save'));
      await tester.pump();

      expect(find.text('Could not save annotation.'), findsOneWidget);
      expect(find.text('New annotation'), findsOneWidget);
    });
  });
}

typedef _Created = ({
  int chapterId,
  int pageNumber,
  AnnotationDraft draft,
  String? comment,
  int selectedSlotIndex,
});

class _RecordingAnnotationActions extends AnnotationActions {
  final created = <_Created>[];
  Object? error;

  @override
  Future<void> create({
    required int chapterId,
    required int pageNumber,
    required AnnotationDraft draft,
    required String? comment,
    required int selectedSlotIndex,
  }) async {
    if (error case final error?) throw error;

    created.add((
      chapterId: chapterId,
      pageNumber: pageNumber,
      draft: draft,
      comment: comment,
      selectedSlotIndex: selectedSlotIndex,
    ));
  }
}

/// Opens the draft sheet as a modal bottom sheet, like the reader does.
Future<_RecordingAnnotationActions> _pumpDraftSheet(
  WidgetTester tester, {
  List<HighlightSlotModel>? slots,
}) async {
  final actions = _RecordingAnnotationActions();
  final repository = MockAnnotationRepository();
  when(
    repository.watchHighlightSlots(),
  ).thenAnswer((_) => Stream.value(slots ?? _slots));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        annotationRepositoryProvider.overrideWithValue(repository),
        annotationActionsProvider.overrideWith(() => actions),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
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
  return actions;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _enterText(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<MockAnnotationRepository> _pumpSheet(
  WidgetTester tester, {
  List<AnnotationModel>? annotations,
  List<HighlightSlotModel>? slots,
  Stream<List<AnnotationModel>>? annotationsStream,
  Stream<List<HighlightSlotModel>>? slotsStream,
}) async {
  final repository = MockAnnotationRepository();
  when(
    repository.watchAnnotations(chapterId: _chapterId),
  ).thenAnswer(
    (_) => annotationsStream ?? Stream.value(annotations ?? [_annotation]),
  );
  when(
    repository.watchHighlightSlots(),
  ).thenAnswer((_) => slotsStream ?? Stream.value(slots ?? _slots));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        annotationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
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
