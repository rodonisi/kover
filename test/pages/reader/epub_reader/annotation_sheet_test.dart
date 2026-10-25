import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/pages/reader/epub_reader/annotation_sheet.dart';
import 'package:kover/riverpod/providers/annotation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  AnnotationModel annotation({String? comment}) {
    return AnnotationModel(
      id: 1,
      serverId: 2,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 0,
      xPath: '//body/p[1]',
      selectedText: 'highlighted words',
      comment: comment,
      selectedSlotIndex: 0,
      containsSpoiler: false,
      ownerUserId: 1,
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    AnnotationModel annotation,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        highlightSlotsProvider.overrideWith(
          (ref) => Stream.value(const [Color(0x66ffff00)]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AnnotationSheet(annotation: annotation)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the highlighted text and its note', (tester) async {
    await pumpSheet(tester, annotation(comment: 'My note'));

    expect(find.text('highlighted words'), findsOneWidget);
    expect(find.text('My note'), findsOneWidget);
    expect(find.text('No note'), findsNothing);
  });

  testWidgets('says when the highlight has no note', (tester) async {
    await pumpSheet(tester, annotation(comment: '  '));

    expect(find.text('highlighted words'), findsOneWidget);
    expect(find.text('No note'), findsOneWidget);
  });
}
