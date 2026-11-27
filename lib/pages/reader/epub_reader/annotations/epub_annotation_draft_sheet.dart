import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_draft.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_editable_body.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_helpers.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_sheet_layout.dart';
import 'package:kover/pages/reader/epub_reader/annotations/epub_annotation_sheet_provider.dart';
import 'package:kover/riverpod/providers/annotations.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

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
    final model = ref.watch(
      epubAnnotationDraftSheetProvider(
        chapterId: chapterId,
        pageNumber: pageNumber,
      ),
    );

    return Async(
      asyncValue: model,
      data: (data) => _DraftContent(
        chapterId: chapterId,
        pageNumber: pageNumber,
        chapterTitle: data.chapterTitle,
        draft: draft,
        slots: data.slots,
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
    final selectedSlot = useState(defaultSlot(slots));
    final containsSpoiler = useState(false);
    final commentController = useMemoized(
      quill.QuillController.basic,
      const [],
    );
    useEffect(() => commentController.dispose, [commentController]);
    final canSave = hasColor(slots, selectedSlot.value);
    final accentColor = colorForSlot(slots, selectedSlot.value);
    final attribution = formatAttribution(
      l,
      pageNumber: pageNumber,
      chapterTitle: chapterTitle,
    );

    Future<void> save() async {
      if (!canSave || isSaving.value) return;

      final messenger = ScaffoldMessenger.of(context);
      isSaving.value = true;
      try {
        await ref
            .read(annotationActionsProvider.notifier)
            .create(
              chapterId: chapterId,
              pageNumber: pageNumber,
              draft: draft,
              comment: commentController.document,
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

    return AnnotationSheetLayout(
      body: AnnotationEditableBody(
        selectedText: draft.selectedText,
        accentColor: accentColor,
        attribution: attribution,
        commentController: commentController,
        slots: slots,
        selectedSlot: selectedSlot.value,
        containsSpoiler: containsSpoiler.value,
        readOnly: isSaving.value,
        onSlotSelected: isSaving.value
            ? null
            : (slot) => selectedSlot.value = slot,
        onSpoilerChanged: isSaving.value
            ? null
            : (value) => containsSpoiler.value = value,
      ),
      footer: AnnotationSaveActions(
        isSaving: isSaving.value,
        onCancel: isSaving.value ? null : () => Navigator.of(context).pop(),
        onSave: canSave && !isSaving.value ? save : null,
      ),
    );
  }
}
