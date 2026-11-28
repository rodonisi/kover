import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_editable_body.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_sheet_layout.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_view_body.dart';
import 'package:kover/pages/reader/epub_reader/annotations/epub_annotation_sheet_provider.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/utils/annotation_comment.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/utils/extensions/app_localizations.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class EpubAnnotationSheet extends HookConsumerWidget {
  final int chapterId;
  final int annotationId;

  const new({
    super.key,
    required this.chapterId,
    required this.annotationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(
      epubAnnotationSheetProvider(
        chapterId: chapterId,
        annotationId: annotationId,
      ),
    );

    return Async(
      asyncValue: model,
      data: (data) {
        if (data == null) {
          return Padding(
            padding: LayoutConstants.largeEdgeInsets,
            child: Text(l.annotationNotFound),
          );
        }

        return _AnnotationContent(model: data);
      },
    );
  }
}

class _AnnotationContent extends HookConsumerWidget {
  const new({required this.model});

  final EpubAnnotationSheetModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final annotation = model.annotation;
    final isEditing = useState(false);
    final isSaving = useState(false);
    final isDeleting = useState(false);
    final selectedSlot = useState(annotation.selectedSlotIndex);
    final containsSpoiler = useState(annotation.containsSpoiler);
    final commentController = useMemoized(
      () => QuillController(
        document: AnnotationComment.toDocument(annotation.comment),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      const [],
    );
    useEffect(() => commentController.dispose, [commentController]);
    final editing = isEditing.value && model.canModify;
    final isBusy = isSaving.value || isDeleting.value;
    final html = annotation.displayCommentHtml;
    final canSave =
        model.canModify && model.slots.colorForSlot(selectedSlot.value) != null;
    final activeSlot = editing
        ? selectedSlot.value
        : annotation.selectedSlotIndex;
    final accentColor = model.slots.colorForSlot(activeSlot);
    final attribution = l.annotationLocation(
      pageNumber: annotation.pageNumber,
      chapterTitle: model.chapterTitle,
    );

    void startEditing() {
      if (!model.canModify) return;
      commentController.document = AnnotationComment.toDocument(
        annotation.comment,
      );
      selectedSlot.value = annotation.selectedSlotIndex;
      containsSpoiler.value = annotation.containsSpoiler;
      isEditing.value = true;
    }

    Future<void> save() async {
      if (!canSave || isBusy) return;

      final messenger = ScaffoldMessenger.of(context);
      isSaving.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .save(
              id: annotation.id,
              comment: commentController.document,
              containsSpoiler: containsSpoiler.value,
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
      if (!model.canModify || isBusy) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.deleteAnnotationDialogTitle),
          content: Text(l.deleteAnnotationDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      isDeleting.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .remove(annotation.id);
        if (context.mounted) Navigator.of(context).pop();
      } catch (error, stacktrace) {
        log.error(
          'failed to delete annotation',
          error: error,
          stacktrace: stacktrace,
        );
        if (context.mounted) isDeleting.value = false;
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.annotationDeleteFailed)),
          );
        }
      }
    }

    return AnnotationSheetLayout(
      body: editing
          ? AnnotationEditableBody(
              selectedText: annotation.selectedText,
              accentColor: accentColor,
              attribution: attribution,
              commentController: commentController,
              slots: model.slots,
              selectedSlot: selectedSlot.value,
              containsSpoiler: containsSpoiler.value,
              readOnly: isBusy,
              onSlotSelected: isBusy
                  ? null
                  : (slot) => selectedSlot.value = slot,
              onSpoilerChanged: isBusy
                  ? null
                  : (value) => containsSpoiler.value = value,
            )
          : AnnotationViewBody(
              header: AnnotationHeader(
                ownerUsername: annotation.ownerUsername,
                timestamp: annotation.lastModified,
                containsSpoiler: annotation.containsSpoiler,
              ),
              selectedText: annotation.selectedText,
              accentColor: accentColor,
              attribution: attribution,
              commentHtml: html,
            ),
      footer: editing
          ? AnnotationSaveActions(
              isSaving: isSaving.value,
              onCancel: isBusy ? null : () => isEditing.value = false,
              onSave: canSave && !isBusy ? save : null,
            )
          : model.canModify
          ? AnnotationViewActions(
              isBusy: isBusy,
              isDeleting: isDeleting.value,
              onDelete: remove,
              onEdit: startEditing,
            )
          : null,
    );
  }
}
