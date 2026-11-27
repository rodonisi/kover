import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/utils/annotation_comment.dart';

void main() {
  group('AnnotationComment', () {
    group('toDocument and fromDocument', () {
      test('roundtrips rich Kavita delta with lists and bold text', () {
        const kavitaDelta =
            r'{"ops":[{"insert":"a"},{"attributes":{"list":"bullet"},"insert":"\n"},{"insert":"a"},{"attributes":{"list":"bullet"},"insert":"\n"},{"insert":"a"},{"attributes":{"list":"ordered"},"insert":"\n"},{"attributes":{"bold":true},"insert":"asd"},{"insert":"\n"}]}';

        final document = AnnotationComment.toDocument(
          comment: kavitaDelta,
          commentPlainText: 'aaaasd',
        );
        final encoded = AnnotationComment.fromDocument(document);

        expect(
          jsonDecode(encoded.comment!),
          jsonDecode(kavitaDelta),
        );
        expect(
          encoded.commentHtml,
          '<ul><li>a</li><li>a</li></ul><ol><li>a</li></ol><p><strong>asd</strong></p>',
        );
        expect(encoded.commentPlainText, 'a\na\na\nasd');
      });

      test('encodes multi-line plain document as separate paragraphs', () {
        final document = quill.Document()..insert(0, 'first\nsecond');
        final encoded = AnnotationComment.fromDocument(document);

        expect(
          encoded.comment,
          r'{"ops":[{"insert":"first\nsecond\n"}]}',
        );
        expect(encoded.commentHtml, '<p>first</p><p>second</p>');
        expect(encoded.commentPlainText, 'first\nsecond');
      });

      test('escapes html markup in plain text', () {
        final document = quill.Document()..insert(0, 'a <b> & c');
        final encoded = AnnotationComment.fromDocument(document);

        expect(encoded.commentHtml, '<p>a &lt;b&gt; &amp; c</p>');
      });

      test('returns empty record for empty or whitespace document', () {
        expect(
          AnnotationComment.fromDocument(quill.Document()),
          AnnotationComment.empty,
        );

        final whitespace = quill.Document()..insert(0, '  \n  ');
        expect(
          AnnotationComment.fromDocument(whitespace),
          AnnotationComment.empty,
        );
      });

      test('decodes empty Kavita note "{}" as empty document', () {
        final document = AnnotationComment.toDocument(
          comment: '{}',
          commentPlainText: '',
        );

        expect(
          AnnotationComment.fromDocument(document),
          AnnotationComment.empty,
        );
      });

      test('decodes non-json comment string into document', () {
        final document = AnnotationComment.toDocument(comment: 'plain note');

        expect(document.toPlainText().trim(), 'plain note');
      });

      test('falls back to commentPlainText when comment is absent', () {
        final document = AnnotationComment.toDocument(
          comment: null,
          commentPlainText: 'fallback note',
        );

        expect(document.toPlainText().trim(), 'fallback note');
      });
    });

    group('toPlainText', () {
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
