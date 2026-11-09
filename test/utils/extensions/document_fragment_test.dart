import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/extensions/document_fragment.dart';
import 'package:kover/utils/extensions/epub_page_preprocessor.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/reflow_engine.dart';

/// Paginates [html] like the epub reader, measuring the buffer by its text
/// length instead of its rendered height.
List<DocumentFragment> paginate(String html, {required int maxChars}) {
  final root = DocumentFragment.html(html).preprocessForRender();
  final engine = ExponentialBinaryReflowEngine(root: root.children.first);
  final subpages = <DocumentFragment>[];

  while (true) {
    if (engine.buffer.text.length <= maxChars) {
      if (!engine.addNext()) {
        subpages.add(DocumentFragment()..append(engine.buffer.clone(true)));
        return subpages;
      }
    } else if (!engine.overflow()) {
      subpages.add(DocumentFragment()..append(engine.commitSplit()));
    }
  }
}

int resumeSubpage(List<DocumentFragment> subpages, String scrollId) {
  return subpages.indexWhere((subpage) => subpage.isResumePoint(scrollId));
}

DocumentFragment subpage(List<Element> paragraphs) {
  return DocumentFragment()
    ..append(Element.tag('div')..nodes.addAll(paragraphs));
}

Element paragraph(String scrollId, String text, {bool split = false}) {
  final p = Element.tag('p')
    ..attributes[HtmlConstants.scrollIdAttribute] = scrollId
    ..append(Text(text));
  if (split) {
    p.attributes[HtmlConstants.splitParagraphAttribute] = '';
  }
  return p;
}

void main() {
  group('isResumePoint', () {
    test('when paragraph is missing, then returns false', () {
      final fragment = subpage([paragraph('a', 'Hello.')]);

      expect(fragment.isResumePoint('b'), isFalse);
    });

    test('when paragraph is empty, then returns false', () {
      final fragment = subpage([
        Element.tag('p')..attributes[HtmlConstants.scrollIdAttribute] = 'a',
      ]);

      expect(fragment.isResumePoint('a'), isFalse);
    });

    test('when paragraph is whole, then returns true', () {
      final fragment = subpage([
        paragraph('a', 'Hello.'),
        paragraph('b', 'There.'),
      ]);

      expect(fragment.isResumePoint('a'), isTrue);
      expect(fragment.isResumePoint('b'), isTrue);
    });

    test(
      'when paragraph is split at the end of the subpage, then returns false',
      () {
        final fragment = subpage([
          paragraph('a', 'Hello.'),
          paragraph('b', 'There.', split: true),
        ]);

        expect(fragment.isResumePoint('b'), isFalse);
      },
    );

    test('when split paragraph fills the subpage, then returns true', () {
      final fragment = subpage([paragraph('a', 'Hello.', split: true)]);

      expect(fragment.isResumePoint('a'), isTrue);
    });

    test(
      'when progress is saved on the continuation of a split paragraph, '
      'then resumes on that subpage',
      () {
        final subpages = paginate(
          '<p>One two three.</p>'
          '<p>Four five six. Seven eight nine. Ten eleven twelve.</p>'
          '<p>Thirteen.</p>',
          maxChars: 35,
        );
        expect(subpages, hasLength(3));

        // The second paragraph starts on the first subpage and continues at
        // the top of the second one, where progress was saved.
        final saved = subpages[1].paragraphScrollId()!;
        expect(subpages[0].paragraphScrollId(), isNot(equals(saved)));
        expect(
          subpages[0].querySelector(
            '[${HtmlConstants.scrollIdAttribute}="$saved"]',
          ),
          isNotNull,
        );

        expect(resumeSubpage(subpages, saved), equals(1));
      },
    );

    test(
      'when progress is saved on whole paragraphs, then resumes on them',
      () {
        final subpages = paginate(
          '<p>One two three.</p>'
          '<p>Four five six. Seven eight nine. Ten eleven twelve.</p>'
          '<p>Thirteen.</p>',
          maxChars: 35,
        );

        for (final index in [0, 2]) {
          final saved = subpages[index].paragraphScrollId()!;
          expect(resumeSubpage(subpages, saved), equals(index));
        }
      },
    );

    test(
      'when split paragraph spans several subpages, '
      'then resumes on the first subpage it starts at the top',
      () {
        final subpages = paginate(
          '<p>One two three.</p>'
          '<p>Four five six. Seven eight nine. Ten eleven twelve.</p>'
          '<p>Thirteen.</p>',
          maxChars: 30,
        );
        expect(subpages, hasLength(3));

        // The same paragraph is on top of both the second and the third
        // subpage: the saved scroll id can't tell them apart.
        final saved = subpages[2].paragraphScrollId()!;
        expect(subpages[1].paragraphScrollId(), equals(saved));

        expect(resumeSubpage(subpages, saved), equals(1));
      },
    );
  });
}
