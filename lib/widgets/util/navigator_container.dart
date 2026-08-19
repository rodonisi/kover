import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/util/breakpoint_builder.dart';
import 'package:material_ui/material_ui.dart';
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

    return Async(
      asyncValue: destinations,
      data: (destinations) {
        final selectedIndex = _mapSelectedIndex(
          shellIndex: navigationShell.currentIndex,
          destinations: destinations,
        );
        void onDestinationSelected(int index) {
          final shellIndex = index < destinations.length
              ? destinations[index].value
              : navigationShell.route.branches.length - 1;
          navigationShell.goBranch(
            shellIndex,
            initialLocation: true,
          );
        }

        return BreakpointBuilder(
          compactBuilder: (context) {
            return _CompactNavigationShell(
              navigationShell: navigationShell,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            );
          },
          expandedBuilder: (context) {
            return _ExpandedNavigationLayout(
              key: const ValueKey('expanded_navigation_layout'),
              navigationShell: navigationShell,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            );
          },
          largestBuilder: (context) {
            return _ExpandedNavigationLayout(
              key: const ValueKey('largest_navigation_layout'),
              navigationShell: navigationShell,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
              startExtended: true,
            );
          },
        );
      },
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

class _CompactNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavbarDestinations> destinations;

  const new({
    required this.navigationShell,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider);

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
            child: Async(
              asyncValue: theme,
              data: (theme) {
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
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
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
}

class _ExpandedNavigationLayout extends HookWidget {
  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavbarDestinations> destinations;
  final bool startExtended;

  const new({
    super.key,
    required this.navigationShell,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.startExtended = false,
  });

  @override
  Widget build(BuildContext context) {
    final extended = useState(startExtended);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended.value,
            scrollable: true,
            trailingAtBottom: true,
            trailing: Padding(
              padding: LayoutConstants.smallestEdgeInsets,
              child: IconButton(
                icon: Icon(
                  extended.value
                      ? KoverIcons.collapsePanel
                      : KoverIcons.expandPanel,
                ),
                onPressed: () {
                  extended.value = !extended.value;
                },
              ),
            ),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              ...destinations.map((destination) {
                return NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(
                    destination.getLabel(AppLocalizations.of(context)),
                  ),
                );
              }),
              NavigationRailDestination(
                icon: const Icon(LucideIcons.library),
                label: Text(AppLocalizations.of(context).menu),
              ),
            ],
          ),
          const VerticalDivider(width: 1.0, thickness: 1.0),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
