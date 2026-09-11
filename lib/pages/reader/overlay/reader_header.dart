import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/overlay/reader_overlay_provider.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

class ReaderHeader extends ConsumerWidget {
  final int seriesId;
  final int? chapterId;
  final int? readingListId;
  final bool hasDrawer;

  const new({
    super.key,
    required this.seriesId,
    this.chapterId,
    this.readingListId,
    this.hasDrawer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = (ref.watch(
      readerOverlayProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ),
    ));

    return SafeArea(
      child: Card.filled(
        margin: LayoutConstants.mediumEdgeInsets,
        child: Padding(
          padding: LayoutConstants.mediumEdgeInsets,
          child: Async(
            asyncValue: model,
            data: (data) => Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .center,
              mainAxisSize: .min,
              spacing: LayoutConstants.smallPadding,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Text(
                        data.reader.chapter.title,
                        textAlign: .center,
                        overflow: .ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium,
                      ),
                      Text(
                        data.reader.series.name,
                        textAlign: .center,
                        overflow: .ellipsis,
                        style:
                            Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (hasDrawer || data.reader.series.format == .epub)
                  IconButton(
                    icon: const Icon(LucideIcons.tableOfContents),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  )
                else
                  const SizedBox.square(
                    dimension: LayoutConstants.mediumIcon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
