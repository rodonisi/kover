import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/horizontal_paged_reader.dart';
import 'package:kover/pages/reader/image_reader/horizontal_spreads_reader.dart';
import 'package:kover/pages/reader/image_reader/vertical_continuous_reader.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/widgets/util/async_value.dart';

class ImageReader extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int? readingListId;

  const ImageReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
    this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));
    final commonSettings = ref.watch(
      commonReaderSettingsProvider(seriesId: seriesId),
    );

    return Async2(
      asyncValue1: settings,
      asyncValue2: commonSettings,
      data: (settings, commonSettings) {
        final navProvider = readerNavigationProvider(
          seriesId: seriesId,
          chapterId: chapterId,
        );

        if (settings.readerMode == .spread) {
          return HorizontalSpreadsReader(
            seriesId: seriesId,
            chapterId: chapterId,
            readingListId: readingListId,
          );
        }

        return ReaderOverlay(
          seriesId: seriesId,
          chapterId: chapterId,
          readingListId: readingListId,
          onNextPage: () {
            commonSettings.readDirection == .leftToRight
                ? ref.read(navProvider.notifier).nextPage()
                : ref.read(navProvider.notifier).previousPage();
          },
          onPreviousPage: () {
            commonSettings.readDirection == .leftToRight
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
