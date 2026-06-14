import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/settings/credentials_settings.dart';
import 'package:kover/pages/settings/data_management_settings.dart';
import 'package:kover/pages/settings/general_settings.dart';
import 'package:kover/pages/settings/version_label.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

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
            const SliverToBoxAdapter(child: CredentialsSettings()),
            const SliverToBoxAdapter(child: GeneralSettings()),
            const SliverToBoxAdapter(child: DataManagementSettings()),
            const SliverToBoxAdapter(
              child: Center(child: VersionLabel()),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
