import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/pages/reader/epub_reader/annotation_actions.dart';
import 'package:kover/pages/reader/epub_reader/annotation_widgets.dart';
import 'package:kover/riverpod/providers/annotation.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

enum _AnnotationAction { edit, delete }

/// Shows the highlighted text of [annotation] and its note in a bottom sheet,
/// from which the owner can edit or delete it.
Future<void> showAnnotationSheet(
  BuildContext context,
  WidgetRef ref, {
  required AnnotationModel annotation,
}) async {
  final action = await showAnnotationBottomSheet<_AnnotationAction>(
    context,
    ref,
    builder: (context) => AnnotationSheet(annotation: annotation),
  );
  if (!context.mounted) return;

  switch (action) {
    case .edit:
      await editAnnotation(context, ref, annotation);
    case .delete:
      await deleteAnnotation(context, ref, annotation);
    case null:
      return;
  }
}

class AnnotationSheet extends ConsumerWidget {
  final AnnotationModel annotation;

  const AnnotationSheet({super.key, required this.annotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    final slots = ref.watch(highlightSlotsProvider).value ?? const [];
    final highlightColor = highlightSlotColor(
      slots,
      annotation.selectedSlotIndex,
    );
    // Shared annotations of other users can only be read.
    final isOwner =
        ref.watch(currentUserProvider).value?.id == annotation.ownerUserId;

    final comment = annotation.comment?.trim() ?? '';
    final lastModified = annotation.lastModified;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        LayoutConstants.mediumPadding,
        0,
        LayoutConstants.mediumPadding,
        LayoutConstants.mediumPadding,
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: LayoutConstants.mediumPadding,
        children: [
          Row(
            spacing: LayoutConstants.smallPadding,
            children: [
              Expanded(
                child: Text(l.annotation, style: textTheme.titleMedium),
              ),
              if (lastModified != null)
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(lastModified.toLocal()),
                  style: textTheme.labelMedium?.copyWith(color: mutedColor),
                ),
            ],
          ),
          AnnotationQuote(
            text: annotation.selectedText,
            color: highlightColor,
          ),
          if (comment.isNotEmpty)
            SelectableText(comment, style: textTheme.bodyLarge)
          else
            Text(
              l.noAnnotationNote,
              style: textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          if (isOwner)
            Row(
              mainAxisAlignment: .end,
              spacing: LayoutConstants.smallPadding,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_AnnotationAction.delete),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(KoverIcons.trash),
                  label: Text(l.delete),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pop(_AnnotationAction.edit),
                  icon: const Icon(KoverIcons.edit),
                  label: Text(l.edit),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
