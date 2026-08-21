import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:kover/utils/epub_font_parser.dart';

void main() {
  group('EpubFontParser', () {
    group('parseCss', () {
      test(
        'when a font-face declares an unquoted family, then extracts it',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: TestFont;
              src: url(fonts://test/regular.ttf);
            }
          ''');

          expect(faces, hasLength(1));
          expect(faces.single.family, 'TestFont');
          expect(faces.single.url, 'fonts://test/regular.ttf');
          expect(faces.single.weight, isNull);
        },
      );

      test(
        'when a font-family is quoted, then the quotes are stripped',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: "Quoted Font";
              src: url("fonts://test/regular.ttf");
            }
          ''');

          expect(faces.single.family, 'Quoted Font');
        },
      );

      test(
        'when a family declares multiple weights, then each face keeps its weight',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: Multi;
              font-weight: 400;
              src: url(fonts://multi/regular.ttf);
            }
            @font-face {
              font-family: Multi;
              font-weight: 700;
              src: url(fonts://multi/bold.ttf);
            }
          ''');

          expect(faces, hasLength(2));
          expect(faces[0].family, 'Multi');
          expect(faces[0].url, 'fonts://multi/regular.ttf');
          expect(faces[0].weight, 400);
          expect(faces[1].url, 'fonts://multi/bold.ttf');
          expect(faces[1].weight, 700);
        },
      );

      test(
        'when a weight is declared as bold, then it maps to 700',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: Boldy;
              font-weight: bold;
              src: url(fonts://boldy/bold.ttf);
            }
          ''');

          expect(faces.single.weight, 700);
        },
      );

      test(
        'when a src lists multiple fallback urls, then only supported are extracted',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: Fallbacks;
              src: url(fonts://f/font.woff2) format("woff2"),
                   url(fonts://f/font.ttf) format("truetype");
            }
          ''');

          expect(faces.map((f) => f.url), [
            'fonts://f/font.ttf',
          ]);
        },
      );

      test(
        'when a face declares no src, then nothing is collected',
        () {
          final faces = EpubFontParser.parseCss('''
            @font-face {
              font-family: NoSrc;
            }
          ''');

          expect(faces, isEmpty);
        },
      );

      test(
        'when the css has no font-face rules, then returns empty',
        () {
          final faces = EpubFontParser.parseCss('''
            body { color: red; }
            p { font-family: Serif; }
          ''');

          expect(faces, isEmpty);
        },
      );

      test(
        'when the css is malformed, then returns empty without throwing',
        () {
          final faces = EpubFontParser.parseCss('@@@ { broken');

          expect(faces, isEmpty);
        },
      );
    });

    group('parseStyles', () {
      test(
        'when multiple style tags declare fonts, then concatenates them in order',
        () {
          final fragment = parseFragment('''
            <style>
              @font-face { font-family: Merged; src: url(fonts://m/a.ttf); }
            </style>
            <style>
              @font-face { font-family: Merged; src: url(fonts://m/b.ttf); }
            </style>
          ''');

          final faces = EpubFontParser.parseStyles(
            fragment.querySelectorAll('style'),
          );

          expect(faces.map((f) => f.url), [
            'fonts://m/a.ttf',
            'fonts://m/b.ttf',
          ]);
        },
      );

      test(
        'when there are no style tags, then returns empty',
        () {
          final fragment = parseFragment('<p>hello</p>');

          final faces = EpubFontParser.parseStyles(
            fragment.querySelectorAll('style'),
          );

          expect(faces, isEmpty);
        },
      );
    });
  });
}
