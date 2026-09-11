import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content_provider.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class RenderEpubContent extends ConsumerWidget {
  final int seriesId;
  final String html;
  final Map<String, Map<String, String>> styles;
  final CachedImageFactory? imageCache;
  final bool verticalPadding;

  const RenderEpubContent({
    super.key,
    required this.seriesId,
    required this.html,
    required this.styles,
    this.imageCache,
    this.verticalPadding = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(
      renderEpubContentProvider(seriesId: seriesId),
    );

    return Async(
      asyncValue: model,
      data: (data) {
        final mergedStyles = Map<String, Map<String, String>>.from(styles);
        for (final entry in data.customCss.entries) {
          mergedStyles[entry.key] = {
            ...mergedStyles[entry.key] ?? {},
            ...entry.value,
          };
        }

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: data.epubSettings.marginSize,
              vertical: verticalPadding ? data.epubSettings.marginSize : 0,
            ),
            child: HtmlWidget(
              html,
              buildAsync: false,
              enableCaching: true,
              factoryBuilder: () => imageCache ?? CachedImageFactory(),
              customStylesBuilder: (element) {
                final s = Map<String, String>.from(
                  mergedStyles[element.localName] ?? {},
                );

                for (final className in element.classes) {
                  s.addAll(mergedStyles['.$className'] ?? {});
                }

                final considerLast =
                    !verticalPadding || element.nextElementSibling != null;

                final isSplit = element.attributes.containsKey(
                  HtmlConstants.splitParagraphAttribute,
                );

                final fontOverride = data.epubSettings.fontFamily;
                if (fontOverride != null) {
                  final fontFamily = 'font-family: "$fontOverride"';
                  element.attributes['style'] =
                      '${element.attributes['style']}; $fontFamily';
                }

                if (element.localName == 'p') {
                  final styles = [?element.attributes['style']];

                  final alignment = switch (data.epubSettings.textAlignment) {
                    EpubTextAlignment.left => 'left',
                    EpubTextAlignment.center => 'center',
                    EpubTextAlignment.right => 'right',
                    EpubTextAlignment.justify => 'justify',
                  };
                  styles.add('text-align: $alignment');

                  if (considerLast && !isSplit) {
                    styles.add(
                      'margin-bottom: ${data.epubSettings.paragraphSpacing}em',
                    );
                  }

                  element.attributes['style'] = styles.whereType<String>().join(
                    '; ',
                  );
                }

                if (data.epubSettings.removeParagraphIndent &&
                    element.attributes.containsKey(
                      HtmlConstants.textIndentSpanAttribute,
                    )) {
                  final textIndent = 'width: 0';
                  element.attributes['style'] =
                      '${element.attributes['style']}; $textIndent';
                }

                return s;
              },
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: data.epubSettings.fontSize,
                height: data.epubSettings.lineHeight,
                wordSpacing: data.epubSettings.wordSpacing,
                letterSpacing: data.epubSettings.letterSpacing,
              ),
              rebuildTriggers: [
                mergedStyles.toString(),
                data.epubSettings,
              ],
            ),
          ),
        );
      },
    );
  }
}
