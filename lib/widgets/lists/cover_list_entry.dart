import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/layout_constants.dart';

class CoverListEntry extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget? cover;
  final Widget? trailing;
  final double? progress;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const CoverListEntry({
    super.key,
    required this.title,
    this.subtitle,
    this.cover,
    this.trailing,
    this.progress,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card.filled(
      clipBehavior: .hardEdge,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: LayoutConstants.smallEdgeInsets,
          child: Row(
            spacing: LayoutConstants.mediumPadding,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  LayoutConstants.smallPadding,
                ),
                child: SizedBox(
                  height: LayoutConstants.largestIcon,
                  child: cover,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: .start,
                  spacing: LayoutConstants.smallPadding,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: .ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: .ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: LayoutConstants.mediumIcon,
                child: CircularProgressIndicator(
                  value: progress,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class CoverListEntryPlaceholder extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card.filled(
          child: Padding(
            padding: LayoutConstants.smallEdgeInsets,
            child: SizedBox(
              height: LayoutConstants.largestIcon,
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 600.ms, angle: 0.45)
        .then(delay: 1000.ms)
        .tint(duration: 0.ms);
  }
}
