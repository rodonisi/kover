import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/navigate_option.dart';

class BottomSheetOption extends ConsumerWidget {
  final String title;
  final IconData? leadingIcon;
  final Widget Function(BuildContext) bottomSheetBuilder;
  const BottomSheetOption({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.bottomSheetBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceAnimations = ref.watch(
      themeProvider.select(
        (value) =>
            value.whenOrNull(
              data: (data) => data.reduceAnimations,
            ) ??
            const ThemeModel().reduceAnimations,
      ),
    );

    final animation = reduceAnimations
        ? const AnimationStyle(duration: .zero, reverseDuration: .zero)
        : null;

    return NavigateOption(
      title: title,
      leadingIcon: leadingIcon,
      onTap: () {
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            maxWidth: LayoutBreakpoints.medium,
          ),
          sheetAnimationStyle: animation,
          builder: bottomSheetBuilder,
        );
      },
    );
  }
}
