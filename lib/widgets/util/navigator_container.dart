import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/riverpod/providers/settings/oneoffs.dart';
import 'package:kover/riverpod/providers/theme.dart' hide Theme;
import 'package:kover/utils/extensions/navbar_destination.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/monitoring_opt_out_popup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NavigatorContainer extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavigatorContainer({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final oneOffs = ref.watch(oneOffsProvider);
    final destinations = ref.watch(
      generalSettingsProvider.select(
        (value) => value.whenData(
          (value) => value.navbarDestinations,
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oneOffs.whenData((oneOffs) async {
        if (!oneOffs.monitoringOptOutPopupShown) {
          await showDialog(
            context: context,
            builder: (context) => const MonitoringOptOutPopup(),
          );
          await ref
              .read(oneOffsProvider.notifier)
              .setMonitoringOptOutPopupShown();
        }
      });
    });

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
          left: LayoutConstants.mediumPadding,
          right: LayoutConstants.mediumPadding,
          bottom: LayoutConstants.mediumPadding,
        ),
        child: SafeArea(
          bottom: !SafePlatform.isIOS, // iOS safe area is way too aggressive
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            removeTop: true,
            child: Async2(
              asyncValue1: ref.watch(themeProvider),
              asyncValue2: destinations,
              data: (theme, destinations) {
                final menuIndex = navigationShell.route.branches.length - 1;
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: .hardEdge,
                  shape: RoundedRectangleBorder(
                    side: theme.outlined
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 2.0,
                          )
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: NavigationBar(
                    selectedIndex: _mapSelectedIndex(
                      shellIndex: navigationShell.currentIndex,
                      destinations: destinations,
                    ),
                    onDestinationSelected: (index) {
                      final shellIndex = index < destinations.length
                          ? destinations[index].value
                          : menuIndex;
                      navigationShell.goBranch(
                        shellIndex,
                        initialLocation: true,
                      );
                    },
                    destinations: [
                      ...destinations.map((destination) {
                        return NavigationDestination(
                          icon: Icon(destination.icon),
                          label: destination.getLabel(l),
                        );
                      }),
                      NavigationDestination(
                        icon: const Icon(LucideIcons.library),
                        label: l.menu,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static int _mapSelectedIndex({
    required int shellIndex,
    required List<NavbarDestinations> destinations,
  }) {
    final index = destinations.indexWhere((d) => d.value == shellIndex);

    if (index < 0) {
      return destinations.length;
    }

    return index;
  }
}
