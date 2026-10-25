import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';
import 'package:kover/utils/quill_note.dart';

void main() {
  group('QuillNote', () {
    test('writes text like the web reader editor', () {
      expect(QuillNote.delta('a b\nc'), r'{"ops":[{"insert":"a b\nc\n"}]}');
      expect(
        QuillNote.html('a <b>\n\n"c" & \'d\''),
        '<p>a&nbsp;&lt;b&gt;</p><p><br></p>'
        '<p>&quot;c&quot;&nbsp;&amp;&nbsp;&#39;d&#39;</p>',
      );
    });

    test('writes an empty note like the web reader', () {
      expect(QuillNote.delta(''), '{}');
      expect(QuillNote.html(''), '');
    });

    test('reads the text of a delta, formatted or not', () {
      expect(QuillNote.text(QuillNote.delta('one\ntwo')), 'one\ntwo');
      expect(
        QuillNote.text(
          '{"ops":[{"insert":"bold","attributes":{"bold":true}},'
          '{"insert":" text\\n"}]}',
        ),
        'bold text',
      );
      expect(QuillNote.text('{}'), '');
    });

    test('reads nothing from text that is not a delta', () {
      expect(QuillNote.text('plain note'), isNull);
      expect(QuillNote.text('[1, 2]'), isNull);
      expect(QuillNote.text(null), isNull);
    });
  });

  group('noteText', () {
    AnnotationDto dto({String? comment, String? commentPlainText}) {
      return AnnotationDto(
        comment: comment,
        commentPlainText: commentPlainText,
        chapterId: 1,
        volumeId: 1,
        seriesId: 1,
        libraryId: 1,
        ownerUserId: 1,
      );
    }

    test('prefers the delta, which keeps the line breaks', () {
      expect(
        dto(
          comment: QuillNote.delta("It's\nmine"),
          commentPlainText: 'It&#39;smine',
        ).noteText,
        "It's\nmine",
      );
    });

    test('falls back to the plain text, then to the raw comment', () {
      expect(
        dto(comment: 'plain', commentPlainText: 'It&#39;s').noteText,
        "It's",
      );
      expect(dto(comment: 'plain', commentPlainText: '').noteText, 'plain');
    });
  });
}
