import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

/// A square preview of a bookmark's page image, used in carousels and the
/// chapter bookmark gallery.
class BookmarkPreviewCard extends ConsumerWidget {
  final BookmarkModel bookmark;
  final VoidCallback? onTap;

  const new({
    super.key,
    required this.bookmark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(bookmarkImageProvider(bookmark));
    final canRead =
        ref.watch(canReadChapterProvider(bookmark.chapterId)).value ?? false;

    return Card(
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: canRead ? onTap : null,
        child: Async(
          asyncValue: image,
          loading: () => const LoadingCover(),
          error: (error, stacktrace) {
            log.error(
              'failed to load bookmark image',
              error: error,
              stacktrace: stacktrace,
            );
            return const _BookmarkPlaceholder();
          },
          data: (data) => Image.memory(
            data.data,
            fit: .cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _BookmarkPlaceholder extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const Card.filled(
      margin: EdgeInsets.zero,
      child: Center(
        child: Icon(KoverIcons.coverPlaceholder),
      ),
    );
  }
}
