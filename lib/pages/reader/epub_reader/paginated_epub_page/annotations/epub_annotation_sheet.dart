import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/utils/annotation_comment.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

const double _highlightAccentWidth = 4.0;
const double _minQuoteHeight = 64.0;
const double _viewQuoteHeightFraction = 0.4;
const double _editQuoteHeightFraction = 0.28;
const double _attributionReserveHeight = 36.0;
const double _compactViewThreshold = 160.0;
const double _compactFormThreshold = 260.0;
const double _fallbackHeightFraction = 0.65;
const double _progressIndicatorSize = 18.0;
const double _progressIndicatorStrokeWidth = 2.0;
const double _colorSlotIconSize = 18.0;
const int _commentMinLines = 3;
const int _compactCommentMinLines = 2;
const int _compactCommentMaxLines = 4;

/// Shows annotation details and controls for editing or removing it.
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
    final annotations = ref.watch(
      chapterAnnotationsProvider(chapterId: chapterId),
    );
    final slots = ref.watch(highlightSlotsProvider);
    final toc = ref.watch(bookChaptersProvider(chapterId: chapterId));
    final currentUserId = ref.watch(
      currentUserProvider.select((user) => user.value?.id),
    );
    final isDeleting = useState(false);
    final lastAnnotation = useRef<AnnotationModel?>(null);

    return Async(
      asyncValue: annotations,
      data: (items) {
        final annotation = items
            .where((item) => item.id == annotationId)
            .firstOrNull;
        if (annotation != null) {
          lastAnnotation.value = annotation;
        }

        // Keep the last visible annotation mounted while our own delete is in
        // flight so marking the row removed locally does not flash "not found".
        final visible =
            annotation ?? (isDeleting.value ? lastAnnotation.value : null);
        if (visible == null) {
          return Padding(
            padding: LayoutConstants.largeEdgeInsets,
            child: Text(l.annotationNotFound),
          );
        }

        final chapterTitle = switch (visible.pageNumber) {
          final page? => toc.whenOrNull(
            data: (chapters) => _chapterTitleForPage(chapters, page),
          ),
          null => null,
        };

        return Async(
          asyncValue: slots,
          data: (slots) => _AnnotationContent(
            annotation: visible,
            slots: slots,
            chapterTitle: chapterTitle,
            canModify:
                currentUserId != null && visible.ownerUserId == currentUserId,
            isDeleting: isDeleting,
          ),
        );
      },
    );
  }
}

/// Shows the editor for a new annotation and creates it on save.
class EpubAnnotationDraftSheet extends ConsumerWidget {
  /// Creates a sheet for annotating [draft] on [pageNumber] of [chapterId].
  const new({
    super.key,
    required this.chapterId,
    required this.pageNumber,
    required this.draft,
  });

  final int chapterId;
  final int pageNumber;
  final AnnotationDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterTitle = ref
        .watch(bookChaptersProvider(chapterId: chapterId))
        .whenOrNull(
          data: (chapters) => _chapterTitleForPage(chapters, pageNumber),
        );

    return Async(
      asyncValue: ref.watch(highlightSlotsProvider),
      data: (slots) => _DraftContent(
        chapterId: chapterId,
        pageNumber: pageNumber,
        chapterTitle: chapterTitle,
        draft: draft,
        slots: slots,
      ),
    );
  }
}

class _DraftContent extends HookConsumerWidget {
  const new({
    required this.chapterId,
    required this.pageNumber,
    required this.chapterTitle,
    required this.draft,
    required this.slots,
  });

  final int chapterId;
  final int pageNumber;
  final String? chapterTitle;
  final AnnotationDraft draft;
  final List<HighlightSlotModel> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isSaving = useState(false);
    final selectedSlot = useState(_defaultSlot(slots));
    final containsSpoiler = useState(false);
    final commentController = useTextEditingController();
    final canSave = _hasColor(slots, selectedSlot.value);
    final accentColor = _colorForSlot(slots, selectedSlot.value);
    final attribution = _formatAttribution(
      l,
      pageNumber: pageNumber,
      chapterTitle: chapterTitle,
    );

    Future<void> save() async {
      if (!canSave || isSaving.value) return;

      final messenger = ScaffoldMessenger.of(context);
      final value = commentController.text.trim();
      isSaving.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .create(
              chapterId: chapterId,
              pageNumber: pageNumber,
              draft: draft,
              comment: value.isEmpty ? null : value,
              containsSpoiler: containsSpoiler.value,
              selectedSlotIndex: selectedSlot.value,
            );
        if (context.mounted) Navigator.of(context).pop();
      } catch (error, stacktrace) {
        log.error(
          'failed to create annotation',
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

    return _SheetLayout(
      body: _EditableBody(
        selectedText: draft.selectedText,
        accentColor: accentColor,
        attribution: attribution,
        commentController: commentController,
        slots: slots,
        selectedSlot: selectedSlot.value,
        containsSpoiler: containsSpoiler.value,
        onSlotSelected: isSaving.value
            ? null
            : (slot) => selectedSlot.value = slot,
        onSpoilerChanged: isSaving.value
            ? null
            : (value) => containsSpoiler.value = value,
      ),
      footer: _SaveActions(
        isSaving: isSaving.value,
        onCancel: isSaving.value ? null : () => Navigator.of(context).pop(),
        onSave: canSave && !isSaving.value ? save : null,
      ),
    );
  }
}

class _AnnotationContent extends HookConsumerWidget {
  const new({
    required this.annotation,
    required this.slots,
    required this.chapterTitle,
    required this.canModify,
    required this.isDeleting,
  });

  final AnnotationModel annotation;
  final List<HighlightSlotModel> slots;
  final String? chapterTitle;
  final bool canModify;
  final ValueNotifier<bool> isDeleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEditing = useState(false);
    final isSaving = useState(false);
    final deleting = useValueListenable(isDeleting);
    final selectedSlot = useState(annotation.selectedSlotIndex);
    final containsSpoiler = useState(annotation.containsSpoiler);
    final commentController = useTextEditingController(
      text: _commentText(annotation),
    );
    final editing = isEditing.value && canModify;
    final isBusy = isSaving.value || deleting;
    final comment = _commentText(annotation).trim();
    final canSave = canModify && _hasColor(slots, selectedSlot.value);
    final activeSlot = editing
        ? selectedSlot.value
        : annotation.selectedSlotIndex;
    final accentColor = _colorForSlot(slots, activeSlot);
    final timestamp = annotation.lastModified ?? annotation.created;
    final attribution = _formatAttribution(
      l,
      pageNumber: annotation.pageNumber,
      chapterTitle: chapterTitle,
    );

    void startEditing() {
      if (!canModify) return;
      commentController.text = _commentText(annotation);
      selectedSlot.value = annotation.selectedSlotIndex;
      containsSpoiler.value = annotation.containsSpoiler;
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
      if (!canModify || isBusy) return;

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

    final hasHeader =
        !editing &&
        ((annotation.ownerUsername?.trim().isNotEmpty ?? false) ||
            timestamp != null ||
            annotation.containsSpoiler);

    return _SheetLayout(
      header: hasHeader
          ? _AnnotationHeader(
              ownerUsername: annotation.ownerUsername,
              timestamp: timestamp,
              containsSpoiler: annotation.containsSpoiler,
            )
          : null,
      body: editing
          ? _EditableBody(
              selectedText: annotation.selectedText ?? '',
              accentColor: accentColor,
              attribution: attribution,
              commentController: commentController,
              slots: slots,
              selectedSlot: selectedSlot.value,
              containsSpoiler: containsSpoiler.value,
              onSlotSelected: isBusy
                  ? null
                  : (slot) => selectedSlot.value = slot,
              onSpoilerChanged: isBusy
                  ? null
                  : (value) => containsSpoiler.value = value,
            )
          : _ViewBody(
              selectedText: annotation.selectedText ?? '',
              accentColor: accentColor,
              attribution: attribution,
              comment: comment,
            ),
      footer: editing
          ? _SaveActions(
              isSaving: isSaving.value,
              onCancel: isBusy ? null : () => isEditing.value = false,
              onSave: canSave && !isBusy ? save : null,
            )
          : canModify
          ? _ViewActions(
              isBusy: isBusy,
              isDeleting: deleting,
              onDelete: remove,
              onEdit: startEditing,
            )
          : null,
    );
  }
}

/// Pinned-chrome sheet shell whose flexible [body] adapts to remaining height.
class _SheetLayout extends StatelessWidget {
  const new({
    this.header,
    required this.body,
    this.footer,
  });

  final Widget? header;
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
            ?header,
            Flexible(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Compact metadata row showing owner username, single timestamp, and spoiler.
class _AnnotationHeader extends StatelessWidget {
  const new({
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

/// View-mode body with independently scrollable selected text and comment.
class _ViewBody extends HookWidget {
  const new({
    required this.selectedText,
    required this.accentColor,
    required this.attribution,
    required this.comment,
  });

  final String selectedText;
  final Color? accentColor;
  final String? attribution;
  final String comment;

  @override
  Widget build(BuildContext context) {
    final fallbackController = useScrollController();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * _fallbackHeightFraction;

        if (comment.isEmpty) {
          return Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: LayoutConstants.smallerPadding,
            children: [
              Flexible(
                child: _QuoteCard(
                  text: selectedText,
                  accentColor: accentColor,
                ),
              ),
              if (attribution case final attributionText?)
                _Attribution(text: attributionText),
            ],
          );
        }

        if (availableHeight < _compactViewThreshold) {
          return Scrollbar(
            controller: fallbackController,
            child: SingleChildScrollView(
              controller: fallbackController,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                spacing: LayoutConstants.mediumPadding,
                children: [
                  _QuoteBlock(
                    text: selectedText,
                    accentColor: accentColor,
                    attribution: attribution,
                    maxCardHeight: _minQuoteHeight,
                  ),
                  Text(comment),
                ],
              ),
            ),
          );
        }

        final sharedHeight = math.max(
          0.0,
          availableHeight -
              _attributionReserveHeight -
              LayoutConstants.mediumPadding,
        );
        final quoteMaxHeight = math.max(
          _minQuoteHeight,
          sharedHeight * _viewQuoteHeightFraction,
        );

        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: LayoutConstants.mediumPadding,
          children: [
            _QuoteBlock(
              text: selectedText,
              accentColor: accentColor,
              attribution: attribution,
              maxCardHeight: quoteMaxHeight,
            ),
            Flexible(
              child: _CommentView(comment: comment),
            ),
          ],
        );
      },
    );
  }
}

/// Edit/draft body with scrollable quote, expandable comment input, and controls.
class _EditableBody extends HookWidget {
  const new({
    required this.selectedText,
    required this.accentColor,
    required this.attribution,
    required this.commentController,
    required this.slots,
    required this.selectedSlot,
    required this.containsSpoiler,
    required this.onSlotSelected,
    required this.onSpoilerChanged,
  });

  final String selectedText;
  final Color? accentColor;
  final String? attribution;
  final TextEditingController commentController;
  final List<HighlightSlotModel> slots;
  final int selectedSlot;
  final bool containsSpoiler;
  final void Function(int slotNumber)? onSlotSelected;
  final ValueChanged<bool>? onSpoilerChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fallbackController = useScrollController();

    final controls = _AnnotationControls(
      slots: slots,
      selectedSlot: selectedSlot,
      containsSpoiler: containsSpoiler,
      onSlotSelected: onSlotSelected,
      onSpoilerChanged: onSpoilerChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * _fallbackHeightFraction;

        if (availableHeight < _compactFormThreshold) {
          return Scrollbar(
            controller: fallbackController,
            child: SingleChildScrollView(
              controller: fallbackController,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                spacing: LayoutConstants.mediumPadding,
                children: [
                  _QuoteBlock(
                    text: selectedText,
                    accentColor: accentColor,
                    attribution: attribution,
                    maxCardHeight: _minQuoteHeight,
                  ),
                  TextField(
                    key: const ValueKey('annotation-comment-field'),
                    controller: commentController,
                    minLines: _compactCommentMinLines,
                    maxLines: _compactCommentMaxLines,
                    textCapitalization: .sentences,
                    decoration: InputDecoration(
                      labelText: l.comment,
                    ),
                  ),
                  controls,
                ],
              ),
            ),
          );
        }

        final quoteMaxHeight = math.max(
          _minQuoteHeight,
          availableHeight * _editQuoteHeightFraction,
        );

        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: LayoutConstants.mediumPadding,
          children: [
            _QuoteBlock(
              text: selectedText,
              accentColor: accentColor,
              attribution: attribution,
              maxCardHeight: quoteMaxHeight,
            ),
            Flexible(
              child: TextField(
                key: const ValueKey('annotation-comment-field'),
                controller: commentController,
                minLines: _commentMinLines,
                maxLines: null,
                textCapitalization: .sentences,
                decoration: InputDecoration(labelText: l.comment),
              ),
            ),
            controls,
          ],
        );
      },
    );
  }
}

/// Selected text card capped at [maxCardHeight] with optional attribution below.
class _QuoteBlock extends StatelessWidget {
  const new({
    required this.text,
    required this.accentColor,
    required this.attribution,
    required this.maxCardHeight,
  });

  final String text;
  final Color? accentColor;
  final String? attribution;
  final double maxCardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: LayoutConstants.smallerPadding,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxCardHeight),
          child: _QuoteCard(text: text, accentColor: accentColor),
        ),
        if (attribution case final attributionText?)
          _Attribution(text: attributionText),
      ],
    );
  }
}

/// Scrollable quote card with a vertical highlight-color bar on the start edge.
class _QuoteCard extends HookWidget {
  const new({
    required this.text,
    required this.accentColor,
  });

  final String text;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();

    return Card.filled(
      key: const ValueKey('annotation-selected-text-card'),
      margin: .zero,
      clipBehavior: .antiAlias,
      child: DecoratedBox(
        key: const ValueKey('annotation-highlight-accent'),
        decoration: BoxDecoration(
          border: switch (accentColor) {
            final color? => BorderDirectional(
              start: BorderSide(
                color: color,
                width: _highlightAccentWidth,
              ),
            ),
            null => null,
          },
        ),
        child: Scrollbar(
          controller: scrollController,
          child: SingleChildScrollView(
            key: const ValueKey('annotation-selected-text-scroll'),
            controller: scrollController,
            padding: LayoutConstants.mediumEdgeInsets,
            child: SizedBox(
              width: .infinity,
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Independently scrollable comment area in view mode.
class _CommentView extends HookWidget {
  const new({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        key: const ValueKey('annotation-comment-scroll'),
        controller: scrollController,
        child: SizedBox(
          width: .infinity,
          child: Text(comment),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: .centerEnd,
      child: Text(
        text,
        textAlign: .end,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Highlight color picker and spoiler toggle for editing or creating annotations.
class _AnnotationControls extends StatelessWidget {
  const new({
    required this.slots,
    required this.selectedSlot,
    required this.containsSpoiler,
    required this.onSlotSelected,
    required this.onSpoilerChanged,
  });

  final List<HighlightSlotModel> slots;
  final int selectedSlot;
  final bool containsSpoiler;
  final void Function(int slotNumber)? onSlotSelected;
  final ValueChanged<bool>? onSpoilerChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSlotSelected = this.onSlotSelected;

    return Row(
      crossAxisAlignment: .center,
      spacing: LayoutConstants.mediumPadding,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: .center,
            spacing: LayoutConstants.smallPadding,
            runSpacing: LayoutConstants.smallPadding,
            children: [
              for (final slot in slots)
                if (slot.color case final color?)
                  _ColorSlot(
                    slotNumber: slot.slotNumber,
                    color: color,
                    selected: slot.slotNumber == selectedSlot,
                    onTap: onSlotSelected == null
                        ? null
                        : () => onSlotSelected(slot.slotNumber),
                  ),
            ],
          ),
        ),
        Row(
          mainAxisSize: .min,
          spacing: LayoutConstants.smallPadding,
          children: [
            Text(
              l.spoiler,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Switch(
              key: const ValueKey('annotation-spoiler-toggle'),
              value: containsSpoiler,
              onChanged: onSpoilerChanged,
            ),
          ],
        ),
      ],
    );
  }
}

/// View-mode pinned footer with delete and edit buttons.
class _ViewActions extends StatelessWidget {
  const new({
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
class _SaveActions extends StatelessWidget {
  const new({
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

class _ColorSlot extends StatelessWidget {
  const new({
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
              : const SizedBox.square(dimension: _colorSlotIconSize),
        ),
      ),
    );
  }
}

/// The comment as plain text. Kavita's plain-text copy has no line breaks, so
/// it is only used when the stored comment cannot be decoded.
String _commentText(AnnotationModel annotation) {
  return AnnotationComment.toPlainText(annotation.comment) ??
      annotation.commentPlainText ??
      '';
}

Color? _colorForSlot(List<HighlightSlotModel> slots, int slotNumber) {
  return slots
      .where((slot) => slot.slotNumber == slotNumber)
      .firstOrNull
      ?.color;
}

bool _hasColor(List<HighlightSlotModel> slots, int slotNumber) {
  return _colorForSlot(slots, slotNumber) != null;
}

/// The slot preselected for a new annotation: Kavita's default slot `0`, or
/// the first slot that has a color.
int _defaultSlot(List<HighlightSlotModel> slots) {
  if (_hasColor(slots, 0)) return 0;

  return slots.where((slot) => slot.color != null).firstOrNull?.slotNumber ?? 0;
}

/// Returns the title of the latest TOC entry starting at or before [page].
String? _chapterTitleForPage(List<BookChapterModel> chapters, int page) {
  String? bestTitle;
  var bestPage = -1;

  void visit(List<BookChapterModel> nodes) {
    for (final node in nodes) {
      final title = node.title.trim();
      if (node.page <= page && node.page >= bestPage && title.isNotEmpty) {
        bestPage = node.page;
        bestTitle = title;
      }
      if (node.children.isNotEmpty) {
        visit(node.children);
      }
    }
  }

  visit(chapters);
  return bestTitle;
}

String? _formatAttribution(
  AppLocalizations l, {
  required int? pageNumber,
  required String? chapterTitle,
}) {
  if (pageNumber == null) return null;
  final displayPage = pageNumber + 1;
  return switch (chapterTitle) {
    final chapter? when chapter.isNotEmpty => l.annotationPageChapterLocation(
      displayPage,
      chapter,
    ),
    _ => l.annotationPageLocation(displayPage),
  };
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatShortDate(local)}, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
