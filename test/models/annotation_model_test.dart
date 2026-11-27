import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/annotation_model.dart';

void main() {
  group('displayCommentHtml', () {
    test('returns null for absent or invisible html', () {
      for (final html in [
        null,
        '',
        '   ',
        '<p><br></p>',
        '<p></p>',
        '<div><p><br/></p></div>',
        '<p>   </p>',
      ]) {
        expect(_annotation(commentHtml: html).displayCommentHtml, isNull);
      }
    });

    test('returns trimmed html with visible text', () {
      expect(
        _annotation(commentHtml: '  <p>note</p>  ').displayCommentHtml,
        '<p>note</p>',
      );
    });

    test('returns html with a visible image', () {
      const html = '<p><img src="cover.png"></p>';

      expect(_annotation(commentHtml: html).displayCommentHtml, html);
    });
  });
}

AnnotationModel _annotation({String? commentHtml}) => AnnotationModel(
  id: 1,
  chapterId: 2,
  pageNumber: 3,
  ownerUserId: 4,
  xPath: '/p',
  endingXPath: '/p',
  selectedText: 'quote',
  comment: '{}',
  commentHtml: commentHtml,
  created: DateTime(2025),
  lastModified: DateTime(2025),
);
