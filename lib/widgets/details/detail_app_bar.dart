import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/series_info_background.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/lists/adaptive_sliver_app_bar.dart';

class DetailAppBar extends HookConsumerWidget {
  final String title;
  final double? progress;
  final String? primaryColor;
  final String? secondaryColor;
  final Widget cover;
  final Widget info;
  final Widget collapsedContinueButton;
  final Widget expandedContinueButton;
  final List<Widget> actions;

  const DetailAppBar({
    super.key,
    required this.title,
    this.progress,
    this.primaryColor,
    this.secondaryColor,
    required this.cover,
    required this.info,
    required this.collapsedContinueButton,
    required this.expandedContinueButton,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveSliverAppBar(
      title: CoverAppBarTitle(
        cover: collapsedContinueButton,
        title: Text(
          title,
          overflow: .fade,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4.0),
        child: LinearProgressIndicator(value: progress),
      ),
      actions: actions,
      background: SeriesInfoBackground(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.largePadding,
        ),
        child: Column(
          spacing: LayoutConstants.largePadding,
          crossAxisAlignment: .start,
          mainAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            const SizedBox.square(dimension: kToolbarHeight),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Row(
              spacing: LayoutConstants.largePadding,
              children: [
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadiusGeometry.circular(
                      LayoutConstants.smallBorderRadius,
                    ),
                    child: cover,
                  ),
                ),
                Expanded(
                  child: info,
                ),
              ],
            ),
            expandedContinueButton,
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class CoverAppBarTitle extends StatelessWidget {
  final Widget? cover;
  final Widget title;

  const CoverAppBarTitle({super.key, required this.title, this.cover});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: LayoutConstants.mediumPadding,
      children: [
        SizedBox.square(
          dimension: kToolbarHeight - LayoutConstants.mediumPadding,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              LayoutConstants.smallerBorderRadius,
            ),
            child: cover,
          ),
        ),
        Flexible(child: title),
      ],
    );
  }
}

class ContinuePointButton extends HookWidget {
  final double? progress;
  final String? title;
  final Widget? cover;
  final bool enabled;
  final VoidCallback? onTap;

  const ContinuePointButton({
    super.key,
    this.progress,
    this.title,
    this.cover,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final alpha = useState(1.0);

    useEffect(() {
      alpha.value = enabled ? 1.0 : 0.6;
      return null;
    }, [enabled]);

    final backgroundColor = enabled
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainer;
    final textColor = enabled
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return AnimatedOpacity(
      opacity: alpha.value,
      duration: 200.ms,
      child: Card(
        margin: EdgeInsets.zero,
        color: backgroundColor,
        clipBehavior: .hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(
            LayoutConstants.mediumBorderRadius,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              spacing: LayoutConstants.mediumPadding,
              mainAxisAlignment: .center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadiusGeometry.circular(
                    LayoutConstants.smallBorderRadius,
                  ),
                  child: SizedBox.square(
                    dimension: LayoutConstants.largerIcon,
                    child: cover,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .center,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        l.continueReading,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                        ),
                      ),
                      if (title != null)
                        Text(
                          title!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: LayoutConstants.largerIcon,
                  child: progress != null
                      ? Padding(
                          padding: LayoutConstants.smallEdgeInsets,
                          child: CircularProgressIndicator(
                            strokeWidth: 10,
                            strokeCap: .round,
                            backgroundColor: theme.colorScheme.onPrimaryFixed,
                            color: theme.colorScheme.primaryFixedDim,
                            value: progress,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContinueButtonImage extends ConsumerWidget {
  final bool enabled;
  final Widget image;
  const ContinueButtonImage({
    super.key,
    this.enabled = true,
    required this.image,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = enabled ? KoverIcons.play : KoverIcons.noConnection;
    final iconColor = enabled
        ? Theme.of(context).colorScheme.primaryFixedDim
        : Theme.of(context).colorScheme.onSurface.withAlpha(0x80);
    return Stack(
      children: [
        Positioned.fill(
          child: SizedBox.square(
            dimension: LayoutConstants.largerIcon,
            child: image,
          ),
        ),
        Align(
          alignment: .center,
          child: Icon(
            icon,
            size: LayoutConstants.largeIcon,
            shadows: const [Shadow(blurRadius: 3)],
            color: iconColor,
          ),
        ),
      ],
    );
  }
}

class TitleContinueButton extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TitleContinueButton({
    super.key,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}
