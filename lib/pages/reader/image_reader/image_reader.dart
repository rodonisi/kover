import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/horizontal_paged_reader.dart';
import 'package:kover/pages/reader/image_reader/horizontal_spreads_reader.dart';
import 'package:kover/pages/reader/image_reader/vertical_continuous_reader.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/widgets/util/async_value.dart';

class ImageReader extends ConsumerWidget {
  final int seriesId;
  final int chapterId;

  const ImageReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));

    return Async(
      asyncValue: settings,
      data: (settings) {
        final navProvider = readerNavigationProvider(
          seriesId: seriesId,
          chapterId: chapterId,
        );

        if (settings.readerMode == .spread) {
          return HorizontalSpreadsReader(
            seriesId: seriesId,
            chapterId: chapterId,
          );
        }

        return ReaderOverlay(
          seriesId: seriesId,
          chapterId: chapterId,
          onNextPage: () {
            settings.readDirection == .leftToRight
                ? ref.read(navProvider.notifier).nextPage()
                : ref.read(navProvider.notifier).previousPage();
          },
          onPreviousPage: () {
            settings.readDirection == .leftToRight
                ? ref.read(navProvider.notifier).previousPage()
                : ref.read(navProvider.notifier).nextPage();
          },
          onJumpToPage: (page) {
            ref.read(navProvider.notifier).jumpToPage(page);
          },
          child: switch (settings.readerMode) {
            .horizontal => HorizontalPagedReader(
              seriesId: seriesId,
              chapterId: chapterId,
            ),
            .vertical => VerticalContinuousReader(
              seriesId: seriesId,
              chapterId: chapterId,
            ),
            _ => throw UnimplementedError(
              'Reader mode ${settings.readerMode} not supported here',
            ),
          },
        );
      },
    );
  }
}
