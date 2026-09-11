import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/horizontal_paged_reader.dart';
import 'package:kover/pages/reader/image_reader/horizontal_spreads_reader.dart';
import 'package:kover/pages/reader/image_reader/image_reader_provider.dart';
import 'package:kover/pages/reader/image_reader/vertical_continuous_reader.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

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
    final model = ref.watch(imageReaderProvider(seriesId: seriesId));

    return Async(
      asyncValue: model,
      data: (data) {
        final navProvider = readerNavigationProvider(
          seriesId: seriesId,
          chapterId: chapterId,
        );

        if (data.mode == .spread) {
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
            ref.read(navProvider.notifier).nextPage();
          },
          onPreviousPage: () {
            ref.read(navProvider.notifier).previousPage();
          },
          onJumpToPage: (page) {
            ref.read(navProvider.notifier).jumpToPage(page);
          },
          child: switch (data.mode) {
            .horizontal => HorizontalPagedReader(
              seriesId: seriesId,
              chapterId: chapterId,
            ),
            .vertical => VerticalContinuousReader(
              seriesId: seriesId,
              chapterId: chapterId,
            ),
            _ => throw UnimplementedError(
              'Reader mode ${data.mode} not supported here',
            ),
          },
        );
      },
    );
  }
}
