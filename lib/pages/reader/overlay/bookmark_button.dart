import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class BookmarkButton extends ConsumerWidget {
  final int seriesId;
  final int chapterId;
  final int? readingListId;

  const new({
    super.key,
    required this.chapterId,
    required this.seriesId,
    required this.readingListId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = currentPageBookmarkProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );
    final isBookmarked = ref.watch(provider);

    return Async(
      asyncValue: isBookmarked,
      data: (bookmarked) {
        final l = AppLocalizations.of(context);
        final icon = bookmarked
            ? KoverIcons.bookmarkOn
            : KoverIcons.bookmarkOff;
        final color = bookmarked ? Theme.of(context).colorScheme.primary : null;
        return IconButton(
          icon: Icon(icon, color: color),
          tooltip: bookmarked ? l.removeBookmark : l.addBookmark,
          onPressed: () {
            ref.read(provider.notifier).toggle();
          },
        );
      },
    );
  }
}
