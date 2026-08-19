import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class SliverSection extends StatelessWidget {
  final String title;
  final EdgeInsets? padding;

  const SliverSection({super.key, required this.title, this.padding});

  @override
  Widget build(BuildContext context) {
    final p =
        padding ??
        const EdgeInsets.only(bottom: LayoutConstants.smallerPadding);

    return SliverPadding(
      padding: p,
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
