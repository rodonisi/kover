import 'package:material_ui/material_ui.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/details/filter_input_field.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class SliverPageShell extends StatelessWidget {
  final String title;
  final List<Widget> appBarActions;
  final TextEditingController filterController;
  final List<Widget> slivers;

  const new({
    super.key,
    required this.title,
    required this.filterController,
    required this.slivers,
    this.appBarActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: .onDrag,
      slivers: [
        SliverAppBar.large(
          title: Text(title),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.smallPadding,
          ),
          actions: appBarActions,
        ),
        SliverSafeArea(
          top: false,
          bottom: false,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.mediumPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: FilterInputField(controller: filterController),
                ),
              ),
              ...slivers,
            ],
          ),
        ),
        const SliverBottomPadding(),
      ],
    );
  }
}
