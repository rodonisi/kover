import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';

class ReaderProgress extends ConsumerWidget {
  final int seriesId;
  final int? chapterId;

  const ReaderProgress({
    super.key,
    required this.seriesId,
    this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(
      readerNavigationProvider(seriesId: seriesId, chapterId: chapterId ?? 0),
    );

    final progress = navState.hasValue
        ? navState.value!.currentPage / (navState.value!.totalPages - 1)
        : null;

    return LinearProgressIndicator(
      value: progress,
    );
  }
}

class SubpageProgress extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  const SubpageProgress({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final reader = ref.watch(
      epubNavigationProvider(seriesId: seriesId, chapterId: chapterId),
    );

    final spreads =
        ref
            .watch(
              epubReaderSettingsProvider(seriesId: seriesId),
            )
            .whenOrNull(data: (data) => data.mode == .spreads) ??
        false;

    final progress = reader.whenOrNull(
      data: (data) => (data.page + 1) / data.totalPages,
    );

    final subpageProgress = reader.whenOrNull(
      data: (data) {
        final reflowStatus = ref
            .read(
              epubReflowProvider(
                seriesId: seriesId,
                chapterId: chapterId,
                page: data.page,
              ),
            )
            .value
            ?.status;
        if (reflowStatus != .done) return null;

        final subpage = spreads ? data.subpage ~/ 2 : data.subpage;
        final total = spreads
            ? (data.totalSubpages + 1) ~/ 2
            : data.totalSubpages;

        if (total == 0) return null;

        return (subpage + 1) / total;
      },
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final stepWidth =
        reader.whenOrNull(
          data: (data) => screenWidth / data.totalPages,
        ) ??
        0.0;
    final offset = reader.whenOrNull(
      data: (data) => stepWidth * data.page,
    );

    return SizedBox(
      height: 4.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: LinearProgressIndicator(
              value: progress,
            ),
          ),
          Positioned(
            left: offset,
            child: SizedBox(
              width: stepWidth,
              child: LinearProgressIndicator(
                value: subpageProgress,
                backgroundColor: theme.colorScheme.tertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
