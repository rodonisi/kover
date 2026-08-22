import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/layout_constants.dart';

typedef SectionGridBuilder<T> =
    Widget Function(
      List<T> items,
      int? rowCount,
      void Function(int crossAxisCount) onCrossAxisCountChanged,
    );

class CollapsibleSection<T> extends HookConsumerWidget {
  final String title;
  final List<T> items;
  final SectionGridBuilder<T> gridBuilder;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.items,
    required this.gridBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final showAll = useState(false);
    final showCollapseButton = useState(true);

    final total = items.length;
    final toShow = showAll.value ? total : 1;

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: LayoutConstants.smallEdgeInsets,
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (showCollapseButton.value)
                  TextButton(
                    onPressed: () {
                      showAll.value = !showAll.value;
                    },
                    child: Text(showAll.value ? l.showLess : l.showMore),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsetsGeometry.symmetric(
            horizontal: LayoutConstants.smallPadding,
          ),
          sliver: gridBuilder(items, toShow, (rowLength) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showCollapseButton.value = total > rowLength;
            });
          }),
        ),
      ],
    );
  }
}
