import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
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

    return Card(
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Async(
          asyncValue: image,
          loading: () => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
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
