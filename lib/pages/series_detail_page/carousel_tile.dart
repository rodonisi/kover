import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class CarouselTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget Function(BuildContext, int) listItemBuilder;
  final int? listItemCount;
  final double height;

  const new({
    super.key,
    required this.title,
    this.onTap,
    required this.listItemBuilder,
    this.listItemCount,
    this.height = LayoutConstants.carouselHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: LayoutConstants.mediumEdgeInsets,
          child: Column(
            spacing: LayoutConstants.smallPadding,
            children: [
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Icon(KoverIcons.chevronRight),
                ],
              ),
              SizedBox(
                height: height,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: .centerLeft,
                      end: .centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        0.02,
                        0.98,
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    scrollDirection: .horizontal,
                    padding: const .symmetric(
                      horizontal: LayoutConstants.smallerPadding,
                    ),
                    itemCount: listItemCount,
                    itemBuilder: listItemBuilder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
