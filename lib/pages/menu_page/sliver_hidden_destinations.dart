import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/menu_page/app_list_tile.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/extensions/navbar_destination.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class SliverHiddenDestinations extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hiddenDestinations = ref.watch(
      generalSettingsProvider.select(
        (state) => state.whenData(
          (state) => NavbarDestinations.values
              .where(
                (destination) =>
                    !state.navbarDestinations.contains(destination),
              )
              .toSet(),
        ),
      ),
    );

    final p =
        padding ?? const .only(bottom: LayoutConstants.listSectionSpacing);

    return AsyncSliver(
      asyncValue: hiddenDestinations,
      data: (hiddenDestinations) {
        if (hiddenDestinations.isEmpty) {
          return const SliverToBoxAdapter();
        }

        final destinationList = hiddenDestinations.toList();

        return SliverPadding(
          padding: p,
          sliver: SliverList.separated(
            itemCount: destinationList.length,
            itemBuilder: (context, index) {
              final destination = destinationList[index];
              return AppListTile(
                title: destination.getLabel(l),
                icon: Icon(destination.icon),
                onTap: () => destination.route.push(context),
              );
            },
            separatorBuilder: (context, _) {
              return const SizedBox(
                height: LayoutConstants.listSpacing,
              );
            },
          ),
        );
      },
    );
  }
}
