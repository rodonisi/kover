import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

const double _progressIndicatorSize = 18.0;
const double _progressIndicatorStrokeWidth = 2.0;

/// Pinned-chrome sheet shell whose flexible [body] adapts to remaining height.
class AnnotationSheetLayout extends StatelessWidget {
  const new({
    super.key,
    required this.body,
    this.footer,
  });

  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LayoutConstants.mediumPadding,
          0,
          LayoutConstants.mediumPadding,
          LayoutConstants.mediumPadding,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: LayoutConstants.mediumPadding,
          children: [
            Flexible(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Compact metadata row showing owner username, single timestamp, and spoiler.
class AnnotationHeader extends StatelessWidget {
  const new({
    super.key,
    required this.ownerUsername,
    required this.timestamp,
    required this.containsSpoiler,
  });

  final String? ownerUsername;
  final DateTime? timestamp;
  final bool containsSpoiler;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final metaStyle = theme.textTheme.labelMedium?.copyWith(color: mutedColor);
    final owner = ownerUsername?.trim();

    return Row(
      crossAxisAlignment: .center,
      spacing: LayoutConstants.smallPadding,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: .center,
            spacing: LayoutConstants.smallPadding,
            runSpacing: LayoutConstants.smallerPadding,
            children: [
              if (owner != null && owner.isNotEmpty)
                Row(
                  mainAxisSize: .min,
                  spacing: LayoutConstants.smallerPadding,
                  children: [
                    Icon(
                      KoverIcons.person,
                      size: LayoutConstants.smallIcon,
                      color: mutedColor,
                    ),
                    Text(owner, style: metaStyle),
                  ],
                ),
              if (timestamp case final time?)
                Text(_formatDateTime(context, time), style: metaStyle),
            ],
          ),
        ),
        if (containsSpoiler)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: const BorderRadius.all(
                Radius.circular(LayoutConstants.largeBorderRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.smallPadding,
                vertical: LayoutConstants.smallerPadding,
              ),
              child: Row(
                mainAxisSize: .min,
                spacing: LayoutConstants.smallerPadding,
                children: [
                  Icon(
                    KoverIcons.warning,
                    size: LayoutConstants.smallerIcon,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  Text(
                    l.spoiler,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// View-mode pinned footer with delete and edit buttons.
class AnnotationViewActions extends StatelessWidget {
  const new({
    super.key,
    required this.isBusy,
    required this.isDeleting,
    required this.onDelete,
    required this.onEdit,
  });

  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: .end,
      spacing: LayoutConstants.smallPadding,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: isBusy ? null : onDelete,
          icon: isDeleting
              ? const SizedBox.square(
                  dimension: _progressIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _progressIndicatorStrokeWidth,
                  ),
                )
              : const Icon(KoverIcons.trash),
          label: Text(l.delete),
        ),
        FilledButton.icon(
          onPressed: isBusy ? null : onEdit,
          icon: const Icon(KoverIcons.edit),
          label: Text(l.edit),
        ),
      ],
    );
  }
}

/// The cancel and save buttons of an annotation form.
class AnnotationSaveActions extends StatelessWidget {
  const new({
    super.key,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final bool isSaving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: .end,
      spacing: LayoutConstants.smallPadding,
      children: [
        TextButton(onPressed: onCancel, child: Text(l.cancel)),
        FilledButton.icon(
          onPressed: onSave,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: _progressIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _progressIndicatorStrokeWidth,
                  ),
                )
              : const Icon(KoverIcons.save),
          label: Text(l.save),
        ),
      ],
    );
  }
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatShortDate(local)}, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
