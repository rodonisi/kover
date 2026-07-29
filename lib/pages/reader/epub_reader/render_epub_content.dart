import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/widgets/util/async_value.dart';

class RenderEpubContent extends ConsumerWidget {
  final int seriesId;
  final String html;
  final Map<String, Map<String, String>> styles;
  final CachedImageFactory? imageCache;

  const RenderEpubContent({
    super.key,
    required this.seriesId,
    required this.html,
    required this.styles,
    this.imageCache,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epubSettings = ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId),
    );
    final css = ref.watch(
      customCssProvider(seriesId: seriesId),
    );

    return Async2(
      asyncValue1: epubSettings,
      asyncValue2: css,
      data: (epubSettings, css) {
        final mergedStyles = Map<String, Map<String, String>>.from(styles);
        for (final entry in css.entries) {
          mergedStyles[entry.key] = {
            ...mergedStyles[entry.key] ?? {},
            ...entry.value,
          };
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(epubSettings.marginSize),
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

                if (element.localName == 'p' &&
                    element.nextElementSibling != null) {
                  final paragraphMargin =
                      'margin-bottom: ${epubSettings.paragraphSpacing}px';

                  element.attributes['style'] =
                      '${element.attributes['style']}; $paragraphMargin';
                }

                return s;
              },
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: epubSettings.fontSize,
                height: epubSettings.lineHeight,
                wordSpacing: epubSettings.wordSpacing,
                letterSpacing: epubSettings.letterSpacing,
              ),
              rebuildTriggers: [
                mergedStyles.toString(),
                epubSettings,
              ],
            ),
          ),
        );
      },
    );
  }
}
