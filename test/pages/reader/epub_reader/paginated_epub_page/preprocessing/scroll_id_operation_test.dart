import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/preprocessing/scroll_id_operation.dart';
import 'package:kover/utils/constants/html_constants.dart';

void main() {
  group('ScrollIdOperation', () {
    test(
      'when entering an element, then writes its xpath as the scroll id',
      () {
        final div = dom.Element.tag('div');
        final p = dom.Element.tag('p');
        div.append(p);

        ScrollIdOperation().enter(p);

        expect(p.attributes[HtmlConstants.scrollIdAttribute], '//div/p[1]');
      },
    );
  });
}
