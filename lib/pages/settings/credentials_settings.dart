import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/server_settings.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CredentialsSettings extends HookConsumerWidget {
  const CredentialsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(credentialsProvider);
    final loginStatus = ref.watch(loginStatusProvider);

    final obscureKey = useState(true);

    return Card(
      margin: LayoutConstants.mediumEdgeInsets,
      child: Padding(
        padding: LayoutConstants.mediumEdgeInsets,
        child: Async(
          asyncValue: settings,
          data: (data) {
            final urlController = TextEditingController(text: data.url);
            final apiKeyController = TextEditingController(text: data.apiKey);

            return Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              spacing: LayoutConstants.mediumPadding,
              children: [
                Text(
                  'Credentials',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                TextField(
                  enabled: loginStatus != .loading,
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                  ),
                ),
                TextField(
                  obscureText: obscureKey.value,
                  enabled: loginStatus != .loading,
                  controller: apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    suffixIcon: Padding(
                      padding: const EdgeInsetsGeometry.symmetric(
                        horizontal: LayoutConstants.smallPadding,
                      ),
                      child: IconButton(
                        onPressed: () {
                          obscureKey.value = !obscureKey.value;
                        },
                        icon: Icon(
                          obscureKey.value
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    const _User(),
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(credentialsProvider.notifier)
                            .updateCredentials(
                              CredentialsState(
                                url: urlController.text,
                                apiKey: apiKeyController.text,
                              ),
                            );
                      },
                      label: const Text('Save'),
                      icon: const Icon(LucideIcons.save),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _User extends ConsumerWidget {
  const _User();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final serverVersion = ref.watch(serverVersionProvider);

    return Async2(
      asyncValue1: currentUser,
      asyncValue2: serverVersion,
      data: (user, version) {
        final name = user.username;
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Row(
          spacing: LayoutConstants.smallPadding,
          children: [
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
      },
      loading: () => const SizedBox.square(
        dimension: LayoutConstants.mediumIcon,
        child: CircularProgressIndicator(),
      ),
      error: (_, _) => Icon(
        LucideIcons.circleX,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
