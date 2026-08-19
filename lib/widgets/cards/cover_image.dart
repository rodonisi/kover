import 'package:flutter_animate/flutter_animate.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SeriesCoverImage extends ConsumerWidget {
  final int seriesId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool usePlaceholder;

  const SeriesCoverImage({
    super.key,
    required this.seriesId,
    this.width,
    this.height,
    this.usePlaceholder = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(seriesCoverProvider(seriesId: seriesId)),
      data: (imageData) => PlaceholderCoverImage(
        image: imageData,
        fit: fit,
        height: height,
        width: width,
        usePlaceholder: usePlaceholder,
      ),
      loading: () => const LoadingCover(),
    );
  }
}

class VolumeCoverImage extends ConsumerWidget {
  final int volumeId;
  final double? width;
  final double? height;
  final bool usePlaceholder;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const VolumeCoverImage({
    super.key,
    required this.volumeId,
    this.width,
    this.height,
    this.usePlaceholder = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(volumeCoverProvider(volumeId: volumeId)),
      data: (imageData) => ClipRRect(
        child: PlaceholderCoverImage(
          image: imageData,
          fit: fit,
          height: height,
          width: width,
          usePlaceholder: usePlaceholder,
        ),
      ),
      loading: () => const LoadingCover(),
    );
  }
}

class ChapterCoverImage extends ConsumerWidget {
  final int chapterId;
  final double? width;
  final double? height;
  final bool usePlaceholder;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ChapterCoverImage({
    super.key,
    required this.chapterId,
    this.width,
    this.height,
    this.usePlaceholder = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(chapterCoverProvider(chapterId: chapterId)),
      data: (imageData) => ClipRRect(
        child: PlaceholderCoverImage(
          image: imageData,
          fit: fit,
          height: height,
          width: width,
          usePlaceholder: usePlaceholder,
        ),
      ),
      loading: () => const LoadingCover(),
    );
  }
}

class CollectionCoverImage extends ConsumerWidget {
  final int collectionId;
  final double? width;
  final double? height;
  final bool usePlaceholder;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CollectionCoverImage({
    super.key,
    required this.collectionId,
    this.width,
    this.height,
    this.usePlaceholder = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(
        collectionCoverProvider(collectionId: collectionId),
      ),
      data: (imageData) => ClipRRect(
        child: PlaceholderCoverImage(
          image: imageData,
          fit: fit,
          height: height,
          width: width,
          usePlaceholder: usePlaceholder,
        ),
      ),
      loading: () => const LoadingCover(),
    );
  }
}

class ReadingListCoverImage extends ConsumerWidget {
  final int readingListId;
  final double? width;
  final double? height;
  final bool usePlaceholder;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ReadingListCoverImage({
    super.key,
    required this.readingListId,
    this.width,
    this.height,
    this.usePlaceholder = true,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Async(
      asyncValue: ref.watch(
        readingListCoverProvider(readingListId: readingListId),
      ),
      data: (imageData) => ClipRRect(
        child: PlaceholderCoverImage(
          image: imageData,
          fit: fit,
          height: height,
          width: width,
          usePlaceholder: usePlaceholder,
        ),
      ),
      loading: () => const LoadingCover(),
    );
  }
}

class PlaceholderCoverImage extends StatelessWidget {
  final ImageModel? image;
  final double? width;
  final double? height;
  final bool usePlaceholder;
  final BoxFit fit;
  const PlaceholderCoverImage({
    super.key,
    this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.usePlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return usePlaceholder
          ? SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: Icon(LucideIcons.image),
              ),
            )
          : const SizedBox.shrink();
    }

    return Image.memory(
      image!.data,
      fit: fit,
      height: height,
      width: width,
    );
  }
}

class LoadingCover extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceAnimations = ref.watch(
      themeProvider.select(
        (theme) => theme.whenData((theme) => theme.reduceAnimations),
      ),
    );

    return Async(
      asyncValue: reduceAnimations,
      data: (reduceAnimations) {
        if (reduceAnimations) {
          return const AspectRatio(
            aspectRatio: LayoutConstants.coverAspectRatio,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return AspectRatio(
              aspectRatio: LayoutConstants.coverAspectRatio,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceBright,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 600.ms,
              angle: 0.45,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(0x33),
            )
            .then(delay: 1000.ms)
            .tint(duration: 0.ms);
      },
    );
  }
}
