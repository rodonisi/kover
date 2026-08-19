import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/settings/appearance_settings.dart';
import 'package:kover/pages/settings/credentials_settings.dart';
import 'package:kover/pages/settings/data_management_settings.dart';
import 'package:kover/pages/settings/general_settings.dart';
import 'package:kover/pages/settings/version_label.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/sliver_adaptive_padding.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:material_ui/material_ui.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l.settings),
          ),
          const SliverSafeArea(
            top: false,
            bottom: false,
            sliver: SliverAdaptivePadding(
              sliver: SliverToBoxAdapter(
                child: Column(
                  spacing: LayoutConstants.listSpacing,
                  children: [
                    CredentialsSettings(),
                    GeneralSettings(),
                    AppearanceSettings(),
                    DataManagementSettings(),
                    VersionLabel(),
                  ],
                ),
              ),
            ),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}
