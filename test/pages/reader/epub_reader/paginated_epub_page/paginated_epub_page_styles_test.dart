import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_styles.dart';

void main() {
  group('settingsStyles', () {
    test('maps paragraph and global settings to CSS declarations', () {
      const settings = PaginatedEpubPageSettings(
        horizontalMarginSize: 0,
        verticalMarginSize: 0,
        fontSize: 14,
        paragraphSpacing: 1.2,
        lineHeight: 1.5,
        wordSpacing: 0,
        letterSpacing: 0,
        fontFamily: 'Book Font',
        removeParagraphIndent: true,
        highlightResumePoint: false,
        canScroll: true,
        reduceAnimations: false,
        textAlignment: .justify,
        mode: .horizontal,
      );

      final styles = settingsStyles(settings);

      expect(styles['p'], {
        'margin-bottom': '1.2em',
        'text-align': 'justify',
      });
      expect(styles['*'], {
        'font-family': '"Book Font"',
        'text-indent': '0',
      });
    });

    test('omits global declarations when not configured', () {
      const settings = PaginatedEpubPageSettings(
        horizontalMarginSize: 0,
        verticalMarginSize: 0,
        fontSize: 14,
        paragraphSpacing: 0,
        lineHeight: 1.5,
        wordSpacing: 0,
        letterSpacing: 0,
        fontFamily: null,
        removeParagraphIndent: false,
        highlightResumePoint: false,
        canScroll: true,
        reduceAnimations: false,
        textAlignment: .left,
        mode: .vertical,
      );

      final styles = settingsStyles(settings);

      expect(styles['p'], {'margin-bottom': '0.0em', 'text-align': 'left'});
      expect(styles.containsKey('*'), isFalse);
    });
  });
}
