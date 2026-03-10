import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/widgets/async_value.dart';

class EpubReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;

  const EpubReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = epubReaderProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    return ReaderOverlay(
      seriesId: seriesId,
      chapterId: chapterId,
      onNextPage: () {
        ref.read(reader.notifier).nextPage();
      },
      onPreviousPage: () {
        ref.read(reader.notifier).previousPage();
      },
      onJumpToPage: (page) {
        ref.read(reader.notifier).jumpToPage(page);
      },
      child: Async(
        asyncValue: ref.watch(reader),
        data: (data) {
          return data.when(
            measuring: (data) {
              return MeasureContent(
                state: data,
                seriesId: seriesId,
                chapterId: chapterId,
              );
            },
            display: (data) => SingleChildScrollView(
              child: RenderContent(
                seriesId: seriesId,
                styles: data.page.styles,
                html: data.subpage.outerHtml,
              ),
            ),
          );
        },
      ),
    );
  }
}

class MeasureContent extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  final Measuring state;
  const MeasureContent({
    super.key,
    required this.state,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = epubReaderProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );
    final key = GlobalKey();

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await WidgetsBinding.instance.endOfFrame;
          final renderBox =
              key.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) {
            return;
          }

          if (renderBox.size.height > constraints.maxHeight) {
            await ref.read(provider.notifier).overflow();
          } else {
            await ref.read(provider.notifier).addElement();
          }
        });

        return Stack(
          children: [
            Positioned.fill(
              child: Offstage(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    RenderContent(
                      seriesId: seriesId,
                      key: key,
                      styles: state.page.styles,
                      html: state.subpage.outerHtml,
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: .center,
              child: CircularProgressIndicator(),
            ),
          ],
        );
      },
    );
  }
}

class RenderContent extends ConsumerWidget {
  final int seriesId;
  final String html;
  final Map<String, Map<String, String>> styles;

  const RenderContent({
    super.key,
    required this.seriesId,
    required this.html,
    required this.styles,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epubSettings = ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId),
    );

    final selectorClassRegex = RegExp(
      r'\.([a-zA-Z0-9_-]+)(?:\s|:|\.|\{|$)[^.]*$',
    );
    final Map<String, List<Map<String, String>>> classStyles = {};
    for (final entry in styles.entries) {
      final match = selectorClassRegex.firstMatch(entry.key);
      if (match != null) {
        classStyles.putIfAbsent(match.group(1)!, () => []).add(entry.value);
      }
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(epubSettings.marginSize),
          child: SelectionArea(
            child: HtmlWidget(
              html,
              buildAsync: false,
              enableCaching: true,
              customStylesBuilder: (element) {
                final s = element.classes
                    .expand((className) => classStyles[className] ?? [])
                    .fold<Map<String, String>>({}, (acc, map) {
                      acc.addAll(map);
                      return acc;
                    });

                s.addAll(styles[element.localName] ?? {});

                return s;
              },
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: epubSettings.fontSize,
                height: epubSettings.lineHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
