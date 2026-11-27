import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_quote.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

const int _commentMinLines = 3;

/// Edit/draft body with scrollable quote, expandable comment input, and controls.
class AnnotationEditableBody extends StatelessWidget {
  const new({
    super.key,
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
  final String attribution;
  final TextEditingController commentController;
  final List<HighlightSlotModel> slots;
  final int selectedSlot;
  final bool containsSpoiler;
  final void Function(int slotNumber)? onSlotSelected;
  final ValueChanged<bool>? onSpoilerChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final controls = AnnotationControls(
      slots: slots,
      selectedSlot: selectedSlot,
      containsSpoiler: containsSpoiler,
      onSlotSelected: onSlotSelected,
      onSpoilerChanged: onSpoilerChanged,
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: LayoutConstants.mediumPadding,
      children: [
        Flexible(
          child: AnnotationQuoteBlock(
            text: selectedText,
            accentColor: accentColor,
            attribution: attribution,
            scrollable: true,
          ),
        ),
        TextField(
          controller: commentController,
          minLines: _commentMinLines,
          maxLines: _commentMinLines,
          textCapitalization: .sentences,
          decoration: InputDecoration(labelText: l.comment),
        ),
        controls,
      ],
    );
  }
}

/// Highlight color picker and spoiler toggle for editing or creating annotations.
class AnnotationControls extends StatelessWidget {
  const new({
    super.key,
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
                  AnnotationColorSlot(
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
              value: containsSpoiler,
              onChanged: onSpoilerChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class AnnotationColorSlot extends StatelessWidget {
  const new({
    super.key,
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
              : const SizedBox.square(
                  dimension: LayoutConstants.smallIcon,
                ),
        ),
      ),
    );
  }
}
