import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/resume_highlight_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('ResumeHighlightOperation', () {
    test('when scroll id matches, then adds the default resume class', () {
      final element = _elementWithScrollId('target');

      ResumeHighlightOperation(scrollId: 'target').enter(element);

      expect(element.classes, contains(HtmlConstants.resumeParagraphClass));
    });

    test('when scroll id does not match, then does not add a class', () {
      final element = _elementWithScrollId('other');

      ResumeHighlightOperation(scrollId: 'target').enter(element);

      expect(element.classes, isEmpty);
    });

    test('when scroll id is null, then does not add a class', () {
      final element = _elementWithScrollId('target');

      ResumeHighlightOperation(scrollId: null).enter(element);

      expect(element.classes, isEmpty);
    });
  });
}

dom.Element _elementWithScrollId(String value) {
  return dom.Element.tag('p')
    ..attributes[HtmlConstants.scrollIdAttribute] = value;
}
