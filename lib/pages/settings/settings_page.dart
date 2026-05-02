import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/settings/credentials_settings.dart';
import 'package:kover/pages/settings/data_management_settings.dart';
import 'package:kover/pages/settings/general_settings.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text('Settings'),
            ),
            SliverToBoxAdapter(child: CredentialsSettings()),
            SliverToBoxAdapter(child: GeneralSettings()),
            SliverToBoxAdapter(child: DataManagementSettings()),
            SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
