import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/settings/appearance_settings.dart';
import 'package:kover/pages/settings/credentials_settings.dart';
import 'package:kover/pages/settings/data_management_settings.dart';
import 'package:kover/pages/settings/general_settings.dart';
import 'package:kover/pages/settings/version_label.dart';
import 'package:kover/widgets/util/breakpoint_builder.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(l.settings),
            ),
            const SliverAdaptivePadding(
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(child: CredentialsSettings()),
                  SliverToBoxAdapter(child: GeneralSettings()),
                  SliverToBoxAdapter(child: AppearanceSettings()),
                  SliverToBoxAdapter(child: DataManagementSettings()),
                  SliverToBoxAdapter(
                    child: Center(child: VersionLabel()),
                  ),
                ],
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
