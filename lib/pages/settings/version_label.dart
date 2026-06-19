import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/package_info.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionLabel extends ConsumerWidget {
  const VersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider);

    return Async(
      asyncValue: info,
      data: (info) {
        return InkWell(
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: info.appName,
              applicationVersion: l.version(info.version, info.buildNumber),
              applicationIcon: Container(
                width: LayoutConstants.largestIcon,
                height: LayoutConstants.largestIcon,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.smallBorderRadius,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.smallBorderRadius,
                  ),
                  child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
                ),
              ),
              children: [
                Column(
                  crossAxisAlignment: .center,
                  spacing: LayoutConstants.mediumPadding,
                  children: [
                    Row(
                      children: [
                        Text('${l.github}: '),
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            LayoutConstants.smallBorderRadius,
                          ),
                          onTap: () {
                            launchUrl(
                              Uri.parse('https://github.com/rodonisi/kover'),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LayoutConstants.smallerPadding,
                              vertical: LayoutConstants.smallestPadding,
                            ),
                            child: Text(
                              'https://github.com/rodonisi/kover',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Text(l.madeWithLove, style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            );
          },
          borderRadius: BorderRadius.circular(
            LayoutConstants.largerBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: LayoutConstants.smallPadding,
              horizontal: LayoutConstants.mediumPadding,
            ),
            child: Text(
              'v${info.version} (${info.buildNumber})',
              style: theme.textTheme.labelMedium,
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
    );
  }
}
