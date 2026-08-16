import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class PeopleRun extends StatelessWidget {
  final String title;
  final List<PersonModel> items;

  const new({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return PillRun(
      title: title,
      items: items
          .map((p) => PillRunItem(label: p.name, icon: KoverIcons.person))
          .toList(),
    );
  }
}

class const PillRunItem({required final String label, final IconData? icon});

class PillRun extends HookWidget {
  final String title;
  final List<PillRunItem> items;
  final int collapsedItemCount;

  const new({
    super.key,
    required this.title,
    required this.items,
    this.collapsedItemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final collapsed = useState(true);
    final displayItems = useMemoized(
      () => collapsed.value ? items.take(collapsedItemCount) : items,
      [collapsed.value, items],
    );

    return Column(
      crossAxisAlignment: .start,
      spacing: LayoutConstants.smallPadding,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        Wrap(
          spacing: LayoutConstants.smallPadding,
          runSpacing: LayoutConstants.smallPadding,
          alignment: .start,
          children: [
            ...displayItems.map(
              (item) => Pill(
                child: Row(
                  mainAxisSize: .min,
                  spacing: LayoutConstants.smallPadding,
                  children: [
                    if (item.icon != null)
                      Icon(item.icon, size: LayoutConstants.smallIcon),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (items.length > collapsedItemCount)
              Pill(
                onTap: () => collapsed.value = !collapsed.value,
                child: Text(
                  collapsed.value
                      ? l.moreCount(items.length - collapsedItemCount)
                      : l.showLess,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const new({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.mediumPadding,
            vertical: LayoutConstants.smallerPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
