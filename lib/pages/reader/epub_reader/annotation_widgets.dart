import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a bottom sheet of the annotation UI, with the options of the
/// settings sheets.
Future<T?> showAnnotationBottomSheet<T>(
  BuildContext context,
  WidgetRef ref, {
  required WidgetBuilder builder,
}) {
  final reduceAnimations =
      ref.read(themeProvider).value?.reduceAnimations ??
      const ThemeModel().reduceAnimations;

  return showModalBottomSheet<T>(
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
    builder: builder,
  );
}

/// The highlighted [text] of an annotation, marked with its highlight
/// [color].
class AnnotationQuote extends StatelessWidget {
  final String text;
  final Color color;

  const AnnotationQuote({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: LayoutConstants.smallPadding + LayoutConstants.smallerPadding,
      ),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: color.withValues(alpha: 1),
            width: LayoutConstants.smallerPadding,
          ),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontStyle: .italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
