import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderHeader extends ConsumerWidget {
  final int seriesId;
  final int? chapterId;
  final bool hasDrawer;

  const ReaderHeader({
    super.key,
    required this.seriesId,
    this.chapterId,
    this.hasDrawer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ref
        .watch(readerProvider(seriesId: seriesId, chapterId: chapterId))
        .value;

    return SafeArea(
      child: Card.filled(
        margin: LayoutConstants.mediumEdgeInsets,
        child: Padding(
          padding: LayoutConstants.mediumEdgeInsets,
          child: Row(
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
                      reader?.chapter.title ?? '',
                      textAlign: .center,
                      overflow: .ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium,
                    ),
                    Text(
                      reader?.series.name ?? '',
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
              if (hasDrawer || reader?.series.format == .epub)
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
    );
  }
}
