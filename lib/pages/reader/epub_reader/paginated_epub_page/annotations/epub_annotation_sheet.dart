import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

/// Shows annotation details and controls for editing or removing it.
class EpubAnnotationSheet extends ConsumerWidget {
  /// Creates a sheet for the annotation with [annotationId] in [chapterId].
  const EpubAnnotationSheet({
    super.key,
    required this.chapterId,
    required this.annotationId,
  });

  final int chapterId;
  final int annotationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annotations = ref.watch(
      chapterAnnotationsProvider(chapterId: chapterId),
    );
    final slots = ref.watch(highlightSlotsProvider);

    return Async(
      asyncValue: annotations,
      data: (items) {
        final annotation = items
            .where((item) => item.id == annotationId)
            .firstOrNull;
        if (annotation == null) {
          return Padding(
            padding: LayoutConstants.largeEdgeInsets,
            child: Text(AppLocalizations.of(context).annotationNotFound),
          );
        }

        return Async(
          asyncValue: slots,
          data: (slots) => _AnnotationContent(
            annotation: annotation,
            slots: slots,
          ),
        );
      },
    );
  }
}

class _AnnotationContent extends HookConsumerWidget {
  const _AnnotationContent({
    required this.annotation,
    required this.slots,
  });

  final AnnotationModel annotation;
  final List<HighlightSlotModel> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEditing = useState(false);
    final isSaving = useState(false);
    final isDeleting = useState(false);
    final selectedSlot = useState(annotation.selectedSlotIndex);
    final commentController = useTextEditingController(
      text: _commentText(annotation),
    );
    final isBusy = isSaving.value || isDeleting.value;
    final comment = _commentText(annotation).trim();
    final canSave = slots.any(
      (slot) => slot.slotNumber == selectedSlot.value && slot.color != null,
    );

    void startEditing() {
      commentController.text = _commentText(annotation);
      selectedSlot.value = annotation.selectedSlotIndex;
      isEditing.value = true;
    }

    Future<void> save() async {
      if (!canSave || isBusy) return;

      final messenger = ScaffoldMessenger.of(context);
      final value = commentController.text.trim();
      isSaving.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .save(
              id: annotation.id,
              comment: value.isEmpty ? null : value,
              containsSpoiler: annotation.containsSpoiler,
              selectedSlotIndex: selectedSlot.value,
            );
        if (context.mounted) isEditing.value = false;
      } catch (error, stacktrace) {
        log.error(
          'failed to save annotation',
          error: error,
          stacktrace: stacktrace,
        );
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.annotationSaveFailed)),
          );
        }
      } finally {
        if (context.mounted) isSaving.value = false;
      }
    }

    Future<void> remove() async {
      if (isBusy) return;

      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteAnnotationDialogTitle),
          content: Text(l10n.deleteAnnotationDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      isDeleting.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .remove(annotation.id);
        if (navigator.mounted) navigator.pop();
      } catch (error, stacktrace) {
        log.error(
          'failed to delete annotation',
          error: error,
          stacktrace: stacktrace,
        );
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.annotationDeleteFailed)),
          );
        }
      } finally {
        if (context.mounted) isDeleting.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LayoutConstants.largePadding,
          0,
          LayoutConstants.largePadding,
          LayoutConstants.largePadding,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: LayoutConstants.largePadding,
          children: [
            Text(l.annotationDetails, style: theme.textTheme.titleLarge),
            if (annotation.containsSpoiler)
              Chip(
                avatar: const Icon(KoverIcons.warning, size: 18),
                label: Text(l.spoiler),
              ),
            _Section(
              label: l.selectedText,
              child: Text(annotation.selectedText ?? ''),
            ),
            if (isEditing.value) ...[
              TextField(
                key: const ValueKey('annotation-comment-field'),
                controller: commentController,
                minLines: 3,
                maxLines: 6,
                textCapitalization: .sentences,
                decoration: InputDecoration(labelText: l.comment),
              ),
              Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                spacing: LayoutConstants.smallPadding,
                children: [
                  Text(
                    l.highlightColor,
                    style: theme.textTheme.titleSmall,
                  ),
                  Wrap(
                    spacing: LayoutConstants.smallPadding,
                    runSpacing: LayoutConstants.smallPadding,
                    children: [
                      for (final slot in slots)
                        if (slot.color case final color?)
                          _ColorSlot(
                            slotNumber: slot.slotNumber,
                            color: color,
                            selected: slot.slotNumber == selectedSlot.value,
                            onTap: isBusy
                                ? null
                                : () => selectedSlot.value = slot.slotNumber,
                          ),
                    ],
                  ),
                ],
              ),
            ] else if (comment.isNotEmpty)
              _Section(label: l.comment, child: Text(comment)),
            if (!isEditing.value) ...[
              if (annotation.pageNumber case final page?)
                _DetailRow(label: l.page, value: '$page'),
              if (annotation.created case final created?)
                _DetailRow(
                  label: l.created,
                  value: _formatDateTime(context, created),
                ),
              if (annotation.lastModified case final modified?)
                _DetailRow(
                  label: l.lastModified,
                  value: _formatDateTime(context, modified),
                ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: .end,
              spacing: LayoutConstants.smallPadding,
              children: [
                if (isEditing.value) ...[
                  TextButton(
                    onPressed: isBusy ? null : () => isEditing.value = false,
                    child: Text(l.cancel),
                  ),
                  FilledButton.icon(
                    onPressed: canSave && !isBusy ? save : null,
                    icon: isSaving.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(KoverIcons.save),
                    label: Text(l.save),
                  ),
                ] else ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: isBusy ? null : remove,
                    icon: isDeleting.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(KoverIcons.trash),
                    label: Text(l.delete),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : startEditing,
                    icon: const Icon(KoverIcons.edit),
                    label: Text(l.edit),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: LayoutConstants.smallPadding,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        Card.filled(
          child: Padding(
            padding: LayoutConstants.mediumEdgeInsets,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: .start,
      spacing: LayoutConstants.mediumPadding,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: theme.textTheme.titleSmall),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _ColorSlot extends StatelessWidget {
  const _ColorSlot({
    required this.slotNumber,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int slotNumber;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = '${l.highlightColor} ${slotNumber + 1}';
    final foreground = ThemeData.estimateBrightnessForColor(color) == .dark
        ? Colors.white
        : Colors.black;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: IconButton.filled(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: color,
            shape: const CircleBorder(),
          ),
          icon: selected
              ? Icon(KoverIcons.check, color: foreground)
              : const SizedBox.square(dimension: 18),
        ),
      ),
    );
  }
}

String _commentText(AnnotationModel annotation) {
  final plainText = annotation.commentPlainText;
  if (plainText != null && plainText.trim().isNotEmpty) return plainText;

  final comment = annotation.comment;
  if (comment != null && comment.trim().isNotEmpty) return comment;

  return plainText ?? comment ?? '';
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatMediumDate(local)}, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
