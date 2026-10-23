import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content_provider.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const highlight = Color(0x6600ff00);

  Future<List<TextSpan>> pumpContent(WidgetTester tester, String html) async {
    final container = ProviderContainer.test(
      overrides: [
        renderEpubContentProvider(seriesId: 1).overrideWith(
          (ref) async => RenderEpubContentModel(
            epubSettings: const EpubReaderSettingsState(),
            customCss: {
              '#${HtmlConstants.highlightIdPrefix}2': {
                'background-color': highlight.toCssRgba(),
              },
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: RenderEpubContent(seriesId: 1, html: html, styles: const {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final spans = <TextSpan>[];
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      text.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
    }
    return spans;
  }

  Color? background(List<TextSpan> spans, String text) {
    final style = spans.firstWhere((s) => s.text == text).style;
    return style?.background?.color ?? style?.backgroundColor;
  }

  testWidgets('colors a highlight by its annotation id', (tester) async {
    final spans = await pumpContent(
      tester,
      '<p>plain <${HtmlConstants.highlightTag} '
      'id="${HtmlConstants.highlightIdPrefix}2">marked</${HtmlConstants.highlightTag}></p>',
    );

    expect(background(spans, 'marked'), isSameColorAs(highlight));
    expect(background(spans, 'plain '), isNull);
  });

  testWidgets('leaves a highlight of an unknown annotation unstyled', (
    tester,
  ) async {
    final spans = await pumpContent(
      tester,
      '<p><${HtmlConstants.highlightTag} '
      'id="${HtmlConstants.highlightIdPrefix}9">marked</${HtmlConstants.highlightTag}></p>',
    );

    expect(background(spans, 'marked'), isNull);
  });
}
