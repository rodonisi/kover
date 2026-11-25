import 'package:flutter_test/flutter_test.dart';
import 'package:kover/utils/annotation_comment.dart';

void main() {
  group('AnnotationComment', () {
    group('toDelta', () {
      test('encodes text as a single insert', () {
        expect(
          AnnotationComment.toDelta('a note'),
          r'{"ops":[{"insert":"a note\n"}]}',
        );
      });

      test('keeps line breaks', () {
        expect(
          AnnotationComment.toDelta('first\r\nsecond'),
          r'{"ops":[{"insert":"first\nsecond\n"}]}',
        );
      });

      test('returns null for blank text', () {
        expect(AnnotationComment.toDelta(null), isNull);
        expect(AnnotationComment.toDelta('  \n '), isNull);
      });
    });

    group('toHtml', () {
      test('encodes every line as a paragraph', () {
        expect(
          AnnotationComment.toHtml('first\nsecond'),
          '<p>first</p><p>second</p>',
        );
      });

      test('escapes markup', () {
        expect(
          AnnotationComment.toHtml('a <b> & c'),
          '<p>a &lt;b&gt; &amp; c</p>',
        );
      });

      test('returns null for blank text', () {
        expect(AnnotationComment.toHtml(null), isNull);
        expect(AnnotationComment.toHtml('   '), isNull);
      });
    });

    group('toPlainText', () {
      test('decodes what toDelta encodes', () {
        const text = 'first\nsecond';

        expect(
          AnnotationComment.toPlainText(AnnotationComment.toDelta(text)),
          text,
        );
      });

      test('joins formatted inserts', () {
        expect(
          AnnotationComment.toPlainText(
            '{"ops":[{"insert":"bold","attributes":{"bold":true}},'
            r'{"insert":" text\n"}]}',
          ),
          'bold text',
        );
      });

      test('returns null for an empty Kavita note', () {
        expect(AnnotationComment.toPlainText('{}'), isNull);
        expect(
          AnnotationComment.toPlainText(r'{"ops":[{"insert":"\n"}]}'),
          isNull,
        );
      });

      test('returns null for content that is not text', () {
        expect(
          AnnotationComment.toPlainText(
            '{"ops":[{"insert":{"image":"data:image/png;base64,AA=="}}]}',
          ),
          isNull,
        );
      });

      test('returns comments that are not a delta unchanged', () {
        expect(AnnotationComment.toPlainText('plain note'), 'plain note');
      });

      test('returns null for blank comments', () {
        expect(AnnotationComment.toPlainText(null), isNull);
        expect(AnnotationComment.toPlainText('  '), isNull);
      });
    });
  });
}
