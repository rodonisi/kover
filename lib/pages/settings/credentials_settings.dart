import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/server_settings.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CredentialsSettings extends ConsumerWidget {
  const CredentialsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(credentialsProvider);
    final loginStatus = ref.watch(loginStatusProvider);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Async(
          asyncValue: settings,
          data: (data) => _CredentialsForm(
            data: data,
            loginStatus: loginStatus,
          ),
        ),
      ),
    );
  }
}

class _CredentialsForm extends HookConsumerWidget {
  final CredentialsState data;
  final LoginStatus loginStatus;

  const _CredentialsForm({required this.data, required this.loginStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final obscureKey = useState(true);
    final urlController = useTextEditingController(text: data.url ?? '');
    final apiKeyController = useTextEditingController(text: data.apiKey ?? '');

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: LayoutConstants.mediumPadding,
      children: [
        Text(
          l.credentials,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextField(
          enabled: loginStatus != .loading,
          controller: urlController,
          decoration: InputDecoration(
            labelText: l.baseUrl,
          ),
        ),
        TextField(
          obscureText: obscureKey.value,
          enabled: loginStatus != .loading,
          controller: apiKeyController,
          decoration: InputDecoration(
            labelText: l.apiKey,
            suffixIcon: Padding(
              padding: const EdgeInsetsGeometry.symmetric(
                horizontal: LayoutConstants.smallPadding,
              ),
              child: IconButton(
                onPressed: () {
                  obscureKey.value = !obscureKey.value;
                },
                icon: Icon(
                  obscureKey.value ? LucideIcons.eye : LucideIcons.eyeOff,
                ),
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: .center,
          mainAxisAlignment: .spaceBetween,
          children: [
            _User(loginStatus: loginStatus),
            FilledButton.icon(
              onPressed: loginStatus == .loading
                  ? null
                  : () {
                      ref
                          .read(credentialsProvider.notifier)
                          .updateCredentials(
                            CredentialsState(
                              url: urlController.text,
                              apiKey: apiKeyController.text,
                            ),
                          );
                    },
              label: Text(l.save),
              icon: const Icon(LucideIcons.save),
            ),
          ],
        ),
      ],
    );
  }
}

class _User extends ConsumerWidget {
  final LoginStatus loginStatus;

  const _User({required this.loginStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return switch (loginStatus) {
      LoginStatus.noCredentials => const SizedBox.shrink(),
      LoginStatus.loading => const SizedBox.square(
        dimension: LayoutConstants.mediumIcon,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      LoginStatus.error => Row(
        spacing: LayoutConstants.smallPadding,
        children: [
          Icon(
            LucideIcons.circleX,
            color: Theme.of(context).colorScheme.error,
          ),
          Text(
            l.invalidCredentials,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      LoginStatus.loggedIn => const _LoggedInUser(),
    };
  }
}

class _LoggedInUser extends ConsumerWidget {
  const _LoggedInUser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref
        .watch(currentUserProvider)
        .whenOrNull(
          data: (user) => user,
        );
    final version = ref
        .watch(serverVersionProvider)
        .whenOrNull(
          data: (version) => version,
        );

    if (user == null) {
      return const SizedBox.square(
        dimension: LayoutConstants.mediumIcon,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final name = user.username;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      spacing: LayoutConstants.smallPadding,
      children: [
        Icon(
          LucideIcons.check,
          color: theme.colorScheme.primary,
          size: LayoutConstants.mediumIcon,
        ),
        CircleAvatar(child: Text(initials)),
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        if (version != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
              vertical: LayoutConstants.smallerPadding,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(
                LayoutConstants.smallPadding,
              ),
            ),
            child: Text(
              'v$version',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}
