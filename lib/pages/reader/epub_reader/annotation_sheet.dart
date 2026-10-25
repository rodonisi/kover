import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/riverpod/providers/annotation.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// Shows the highlighted text of [annotation] and its note in a bottom sheet.
Future<void> showAnnotationSheet(
  BuildContext context,
  WidgetRef ref, {
  required AnnotationModel annotation,
}) {
  final reduceAnimations =
      ref.read(themeProvider).value?.reduceAnimations ??
      const ThemeModel().reduceAnimations;

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      maxWidth: LayoutBreakpoints.medium,
    ),
    sheetAnimationStyle: reduceAnimations
        ? const AnimationStyle(duration: .zero, reverseDuration: .zero)
        : null,
    builder: (context) => AnnotationSheet(annotation: annotation),
  );
}

class AnnotationSheet extends ConsumerWidget {
  final AnnotationModel annotation;

  const AnnotationSheet({super.key, required this.annotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final slots = ref.watch(highlightSlotsProvider).value ?? const [];
    final highlightColor = highlightSlotColor(
      slots,
      annotation.selectedSlotIndex,
    ).withValues(alpha: 1);

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
          Container(
            padding: const EdgeInsetsDirectional.only(
              start:
                  LayoutConstants.smallPadding + LayoutConstants.smallerPadding,
            ),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: highlightColor,
                  width: LayoutConstants.smallerPadding,
                ),
              ),
            ),
            child: Text(
              annotation.selectedText,
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: .italic,
                color: mutedColor,
              ),
            ),
          ),
          if (comment.isNotEmpty)
            SelectableText(comment, style: textTheme.bodyLarge)
          else
            Text(
              l.noAnnotationNote,
              style: textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
        ],
      ),
    );
  }
}
