import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_quote.dart';
import 'package:kover/utils/annotation_image.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:material_ui/material_ui.dart';

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
    this.readOnly = false,
  });

  final String selectedText;
  final Color? accentColor;
  final String attribution;
  final QuillController commentController;
  final List<HighlightSlotModel> slots;
  final int selectedSlot;
  final bool containsSpoiler;
  final void Function(int slotNumber)? onSlotSelected;
  final ValueChanged<bool>? onSpoilerChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final controls = AnnotationControls(
      slots: slots,
      selectedSlot: selectedSlot,
      containsSpoiler: containsSpoiler,
      onSlotSelected: onSlotSelected,
      onSpoilerChanged: onSpoilerChanged,
    );

    return SingleChildScrollView(
      padding: const .symmetric(
        horizontal: LayoutConstants.mediumPadding,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: LayoutConstants.mediumPadding,
        children: [
          AnnotationQuoteBlock(
            text: selectedText,
            accentColor: accentColor,
            attribution: attribution,
          ),
          AnnotationCommentEditor(
            controller: commentController,
            readOnly: readOnly,
          ),
          controls,
        ],
      ),
    );
  }
}

Future<void> _insertImage(
  BuildContext context,
  AppLocalizations l,
  String image,
  QuillController controller,
) async {
  try {
    final source = await AnnotationImage.toPortableSource(image);
    AnnotationImage.insert(controller: controller, source: source);
  } catch (error, stacktrace) {
    log.error(
      'failed to insert annotation image',
      error: error,
      stacktrace: stacktrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.annotationImageInsertFailed)),
      );
    }
  }
}

class AnnotationCommentEditor extends HookWidget {
  static const double _editorMinHeight = 84.0;

  const new({
    super.key,
    required this.controller,
    this.readOnly = false,
  });

  final QuillController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final focusNode = useFocusNode();
    final scrollController = useScrollController();
    useListenable(focusNode);

    controller.readOnly = readOnly;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        IgnorePointer(
          ignoring: readOnly,
          child: QuillSimpleToolbar(
            controller: controller,
            config: QuillSimpleToolbarConfig(
              multiRowsDisplay: true,
              toolbarIconAlignment: .start,
              showDividers: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showListBullets: true,
              showListNumbers: true,
              showQuote: true,
              showClearFormat: true,
              showUndo: true,
              showRedo: true,
              showFontSize: false,
              showFontFamily: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showHeaderStyle: false,
              showListCheck: false,
              showCodeBlock: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showAlignmentButtons: false,
              embedButtons: FlutterQuillEmbeds.toolbarButtons(
                videoButtonOptions: null,
                imageButtonOptions: QuillToolbarImageButtonOptions(
                  imageButtonConfig: QuillToolbarImageConfig(
                    onImageInsertCallback: (image, controller) =>
                        _insertImage(context, l, image, controller),
                  ),
                ),
              ),
            ),
          ),
        ),
        QuillEditor(
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          config: QuillEditorConfig(
            placeholder: l.comment,
            minHeight: _editorMinHeight,
            scrollable: false,
            embedBuilders: [
              QuillEditorImageEmbedBuilder(
                config: QuillEditorImageEmbedConfig(
                  imageErrorWidgetBuilder: (context, error, stacktrace) =>
                      Semantics(
                        label: l.annotationImageLoadFailed,
                        child: const Icon(KoverIcons.imageError),
                      ),
                ),
              ),
            ],
            customStyles: DefaultStyles(
              paragraph: DefaultTextBlockStyle(
                theme.textTheme.bodyMedium!,
                .zero,
                .zero,
                .zero,
                null,
              ),
              placeHolder: DefaultTextBlockStyle(
                theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                .zero,
                .zero,
                .zero,
                null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
