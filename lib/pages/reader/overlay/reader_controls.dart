import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/epub_reader/epub_reader_controls.dart';
import 'package:kover/pages/reader/image_reader/image_reader_controls.dart';
import 'package:kover/pages/reader/overlay/page_slider.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderControls extends HookConsumerWidget {
  final int seriesId;
  final int? chapterId;
  final void Function(int page)? onJumpToPage;
  const ReaderControls({
    super.key,
    required this.seriesId,
    this.chapterId,
    this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(
      readerProvider(seriesId: seriesId, chapterId: chapterId).select(
        (state) => state.value?.series.format,
      ),
    );

    return Card.filled(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.smallEdgeInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: .end,
          children: [
            Row(
              children: [
                Expanded(
                  child: PageSlider(
                    seriesId: seriesId,
                    chapterId: chapterId,
                    onJumpToPage: (page) => ref
                        .read(
                          readerNavigationProvider(
                            seriesId: seriesId,
                            chapterId: chapterId,
                          ).notifier,
                        )
                        .jumpToPage(page),
                  ),
                ),
                if (format == .epub)
                  ReaderSettingsButton(
                    child: EpubReaderSettingsBottomSheet(seriesId: seriesId),
                  ),
                if (format == .archive)
                  ReaderSettingsButton(
                    child: ImageReaderSettingsBottomSheet(seriesId: seriesId),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderSettingsButton extends StatelessWidget {
  final Widget child;
  const ReaderSettingsButton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.slidersHorizontal),
      tooltip: 'Reader Settings',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            maxWidth: Breakpoints.medium,
          ),
          builder: (context) => child,
        );
      },
    );
  }
}
