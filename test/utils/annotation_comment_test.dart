import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/utils/annotation_comment.dart';

void main() {
  group('AnnotationComment', () {
    test('roundtrips rich Kavita delta with lists and bold text', () {
      const kavitaDelta =
          r'{"ops":[{"insert":"a"},{"attributes":{"list":"bullet"},"insert":"\n"},{"insert":"a"},{"attributes":{"list":"bullet"},"insert":"\n"},{"insert":"a"},{"attributes":{"list":"ordered"},"insert":"\n"},{"attributes":{"bold":true},"insert":"asd"},{"insert":"\n"}]}';

      final document = AnnotationComment.toDocument(kavitaDelta);
      final encoded = AnnotationComment.fromDocument(document);

      expect(jsonDecode(encoded.comment), jsonDecode(kavitaDelta));
      expect(
        encoded.commentHtml,
        '<ul><li>a</li><li>a</li></ul><ol><li>a</li></ol><p><strong>asd</strong></p>',
      );
    });

    test('encodes multi-line plain document as separate paragraphs', () {
      final document = quill.Document()..insert(0, 'first\nsecond');
      final encoded = AnnotationComment.fromDocument(document);

      expect(
        encoded.comment,
        r'{"ops":[{"insert":"first\nsecond\n"}]}',
      );
      expect(encoded.commentHtml, '<p>first</p><p>second</p>');
    });

    test('escapes html markup in plain text', () {
      final document = quill.Document()..insert(0, 'a <b> & c');
      final encoded = AnnotationComment.fromDocument(document);

      expect(encoded.commentHtml, '<p>a &lt;b&gt; &amp; c</p>');
    });

    test('returns an empty delta for empty or whitespace documents', () {
      expect(
        AnnotationComment.fromDocument(quill.Document()),
        AnnotationComment.empty,
      );

      final whitespace = quill.Document()..insert(0, '  \n  ');
      expect(
        AnnotationComment.fromDocument(whitespace),
        AnnotationComment.empty,
      );
      expect(AnnotationComment.empty.comment, '{}');
    });

    test('decodes an empty Kavita note as an empty document', () {
      final document = AnnotationComment.toDocument('{}');

      expect(
        AnnotationComment.fromDocument(document),
        AnnotationComment.empty,
      );
    });
  });
}
