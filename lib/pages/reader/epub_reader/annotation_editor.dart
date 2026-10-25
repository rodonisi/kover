import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/pages/reader/epub_reader/annotation_widgets.dart';
import 'package:kover/riverpod/providers/annotation.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// What the annotation editor returns.
typedef AnnotationDraft = ({
  String comment,
  int selectedSlotIndex,
  bool containsSpoiler,
});

/// Opens the editor of a highlight of [selectedText], prefilled from
/// [annotation] when editing one. Returns null when cancelled.
Future<AnnotationDraft?> showAnnotationEditor(
  BuildContext context,
  WidgetRef ref, {
  required String selectedText,
  AnnotationModel? annotation,
}) {
  return showAnnotationBottomSheet<AnnotationDraft>(
    context,
    ref,
    builder: (context) =>
        AnnotationEditor(selectedText: selectedText, annotation: annotation),
  );
}

class AnnotationEditor extends HookConsumerWidget {
  final String selectedText;
  final AnnotationModel? annotation;

  const AnnotationEditor({
    super.key,
    required this.selectedText,
    this.annotation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    final storedSlots = ref.watch(highlightSlotsProvider).value ?? const [];
    final slots = storedSlots.isEmpty
        ? const [defaultHighlightColor]
        : storedSlots;

    final slot = useState(annotation?.selectedSlotIndex ?? 0);
    final spoiler = useState(annotation?.containsSpoiler ?? false);
    final note = useTextEditingController(text: annotation?.comment ?? '');

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        LayoutConstants.mediumPadding,
        0,
        LayoutConstants.mediumPadding,
        LayoutConstants.mediumPadding + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: LayoutConstants.mediumPadding,
        children: [
          Text(
            annotation == null ? l.newHighlight : l.editAnnotation,
            style: textTheme.titleMedium,
          ),
          AnnotationQuote(
            text: selectedText,
            color: highlightSlotColor(slots, slot.value),
          ),
          Wrap(
            spacing: LayoutConstants.smallPadding,
            runSpacing: LayoutConstants.smallPadding,
            children: [
              for (final (index, color) in slots.indexed)
                _SlotButton(
                  color: color,
                  selected: index == slot.value,
                  label: l.highlightColor(index + 1),
                  onTap: () => slot.value = index,
                ),
            ],
          ),
          TextField(
            controller: note,
            minLines: 3,
            maxLines: 8,
            textCapitalization: .sentences,
            decoration: InputDecoration(
              hintText: l.annotationNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: .zero,
            title: Text(l.containsSpoilers),
            value: spoiler.value,
            onChanged: (value) => spoiler.value = value,
          ),
          Row(
            mainAxisAlignment: .end,
            spacing: LayoutConstants.smallPadding,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  comment: note.text.trim(),
                  selectedSlotIndex: slot.value,
                  containsSpoiler: spoiler.value,
                )),
                child: Text(l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  static const double _size = 36;

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _SlotButton({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: _size / 2 + LayoutConstants.smallerPadding,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 1),
            shape: .circle,
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  KoverIcons.check,
                  size: LayoutConstants.smallIcon,
                  color: colorScheme.onSurface,
                )
              : null,
        ),
      ),
    );
  }
}
