import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reader/epub_reader/render_epub_content.dart';
import 'package:kover/utils/cached_image_factory.dart';
import 'package:kover/utils/headless_measure_pipeline.dart';

class EpubMeasureRoot extends StatelessWidget {
  final ProviderContainer container;
  final MediaQueryData mediaQueryData;
  final ThemeData themeData;
  final TextDirection textDirection;
  final Locale locale;
  final int seriesId;
  final String html;
  final Map<String, Map<String, String>> styles;
  final CachedImageFactory? imageCache;

  const EpubMeasureRoot({
    super.key,
    required this.container,
    required this.mediaQueryData,
    required this.themeData,
    required this.textDirection,
    required this.locale,
    required this.seriesId,
    required this.html,
    required this.styles,
    this.imageCache,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: .min,
      children: [
        MeasureTarget(
          child: RenderEpubContent(
            seriesId: seriesId,
            styles: styles,
            html: html,
            imageCache: imageCache,
          ),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: MediaQuery(
          data: mediaQueryData,
          child: Theme(
            data: themeData,
            child: Directionality(
              textDirection: textDirection,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
